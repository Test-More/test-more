package Test::Stream::Workflow::Runner;
use strict;
use warnings;

use Carp qw/confess cluck/;

use Scalar::Util qw/reftype/;

use Test::Stream::Plugin::Subtest qw/buffered/;

use Test::Stream::Capabilities qw/CAN_FORK/;
use Test::Stream::Util qw/try/;

use Test::Stream::Workflow::Unit;
use Test::Stream::HashBase;
use Test::Stream::Context qw/context/;

sub import {
    my $class  = shift;
    my $caller = caller;

    require Test::Stream::Workflow::Meta;
    my $meta = Test::Stream::Workflow::Meta->get($class) || return;
    $meta->set_runner($class->new(@_));
}

my %SUPPORTED = map {$_ => 1} qw/todo skip fork/;
sub verify_meta {
    my $class = shift;
    my ($ctx, $meta) = @_;
    return unless $meta;
    for my $k (keys %$meta) {
        next if $SUPPORTED{$k};
        $ctx->alert("'$k' is not a recognised meta-key");
    }
}

sub VARS { }

sub run {
    my $self = shift;
    my %params = @_;
    my $unit = $params{unit};
    my $clutch_ref = $params{clutch};
    my $no_final = $params{no_final};

    my $ctx = $params{context} = $unit->context;

    # Skip?
    if ($ctx->debug->skip) {
        $ctx->ok(1, $unit->name);
        return;
    }

    if (my $only = $ENV{TS_WORKFLOW}) {
        return unless $no_final || $unit->contains($only);
    }

    # Make sure we have something to do!
    my $primary = $unit->primary;
    return $ctx->ok(
        0,
        $unit->name,
        ['No primary actions defined!']
    ) unless $primary;

    my $events = 0;
    my $fail   = 0;

    my $task = $self->build_task(%params);

    my $l = $ctx->hub->listen(sub {
        my ($hub, $e) = @_;
        $events++;
        return if $clutch_ref && $$clutch_ref;
        $fail ||= $e->causes_fail;
    });

    my ($e, $err, $ok, @diag);
    my $run = sub {
        ($e, $err) = try {
            ($ok, @diag) = $self->run_task(
                context => $ctx,
                task    => $task,
                meta    => $unit->meta,
                name    => $unit->name,
                runner  => $self,
            );
        };
    };

    if ($unit->type eq 'group' || !$no_final) {
        my $inner = $run;
        $run = sub {
            my $vars = {};
            my $oldsub = __PACKAGE__->can('VARS');
            no warnings 'redefine';
            *VARS = sub { $vars };

            $inner->();

            no warnings 'redefine';
            *VARS = $oldsub;
            # In case something is holding a reference to vars itself.
            %$vars = ();
            $vars = undef;
        };
    }

    $run->();

    cull();

    $ctx->hub->unlisten($l);

    my $subtest = !($no_final || $params{no_subtest});

    unless($events || $no_final) {
        $fail ||= 1;
        unshift @diag => "No events were run";
    }

    if (!$e) {
        $ok = 0;
        $params{context}->send_event('Exception', error => $err);
    }

    return if $subtest && $e; # Subtests handle their own ok's, unless there is an exception.
    $ctx->ok($ok && !$fail, $unit->name, \@diag) if ($fail || !$ok) || !$no_final;
}

sub build_task {
    my $self = shift;
    my %params = @_;

    my $unit = $params{unit};
    my $args = $params{args};
    my $subtest = !($params{no_final} || $params{no_subtest});

    my $primary  = $unit->primary;
    my $modify   = $unit->modify;
    my $buildup  = $unit->buildup;
    my $teardown = $unit->teardown;

    my $stage = 0;
    my $bidx  = 0;
    my $tidx  = 0;
    my $out   = 1;

    my $task = sub {
        my $recurse = shift;

        my $ran = 0;
        my $clutch = 0;
        my $real_recurse = sub {
            $ran++;
            $clutch++;
            my ($ok, $err) = &try($recurse);
            $unit->context->send_event('Exception', error => $err) unless $ok;
            $clutch--;
        };

        # Run buildups
        while ($stage == 0 && $buildup && $bidx < @$buildup) {
            my $bunit = $buildup->[$bidx++];
            if ($bunit->wrap) {
                $self->run(unit => $bunit, no_final => 1, clutch => \$clutch, args => [$real_recurse]);
                unless ($ran) {
                    $stage = 3;
                    $out = 0;
                    my $ctx = $bunit->context;
                    $bunit->context->send_event(
                        'Exception',
                        error => "Inner sub was never called " . $ctx->debug->detail . "\n",
                    );
                    return $out;
                }
            }
            else {
                $self->run(unit => $bunit, no_final => 1, args => $args);
            }
        }

        $stage = 1 if $stage == 0;

        # run primaries (for each modifier)
        if ($stage == 1) {
            $stage = 2;

            if ($modify) {
                for my $mod (@$modify) {
                    my $temp = Test::Stream::Workflow::Unit->new(
                        %$mod,
                        primary => sub {
                            $mod->primary->(@$args);
                            $self->run(unit => $_, args => $args) for @$primary;
                        },
                    );
                    $self->run(unit => $temp, args => $args);
                }
            }
            elsif(reftype($primary) eq 'ARRAY') {
                $self->run(unit => $_, args => $args) for @$primary
            }
            else {
                $primary->(@$args);
            }
        }

        # Run teardowns
        while($stage == 2 && $teardown && $tidx < @$teardown) {
            my $tunit = $teardown->[$tidx++];
            if ($tunit->wrap) {
                # Popping a wrap
                return $out;
            }
            $self->run(unit => $tunit, no_final => 1, args => $args);
        }

        $stage = 3;

        return $out;
    };

    if ($subtest) {
        my $ctx = $params{context};
        my $inner = $task;
        $task = sub { $ctx->do_in_context(\&subtest, $unit->name, $inner, $inner) };
    }

    return $task;
}

sub run_task {
    my $self = shift;
    my %params = @_;

    $self->verify_meta($params{context}, $params{meta});

    return $self->fork_task(%params) if $params{meta}->{fork};
    $params{task}->($params{task});
}

sub fork_task {
    my $self = shift;
    my %params = @_;

    $params{context}->throw("Cannot fork for '$params{name}', system does not support forking")
        unless CAN_FORK;

    my $pid = fork;
    $params{context}->throw("Fork failed for '$params{name}'")
        unless defined $pid;

    if ($pid) {
        waitpid($pid, 0);
        my $ecode = $? >> 8;
        return (0, "Child process ($pid) exited $ecode") if $ecode;
        return (1);
    }

    my ($ok, $err) = try {
        $params{task}->($params{task});
        cull();
        exit 0;
    };

    cull();
    $params{context}->send_event('Exception', error => $err);
    exit 255;
}

sub cull {
    my $ctx = context();
    $ctx->hub->cull;
    $ctx->release;
}

1;
