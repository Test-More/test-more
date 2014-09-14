package Test::Stream;
use strict;
use warnings;

our $VERSION = '1.301001_041';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use Test::Stream::Threads;
use Test::Stream::IOSets;
use Test::Stream::Util qw/try/;
use Test::Stream::Carp qw/croak confess/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw{
        no_ending no_diag no_header
        pid tid
        state
        listeners mungers
        bailed_out
        exit_on_disruption
        use_tap use_legacy _use_fork
        use_numbers
        io_sets
        event_id
    };
    Test::Stream::ArrayBase->cleanup;
}

use constant STATE_COUNT   => 0;
use constant STATE_FAILED  => 1;
use constant STATE_PLAN    => 2;
use constant STATE_PASSING => 3;
use constant STATE_LEGACY  => 4;
use constant STATE_ENDED   => 5;

use constant OUT_STD  => 0;
use constant OUT_ERR  => 1;
use constant OUT_TODO => 2;

use Test::Stream::Exporter;
exports qw/OUT_STD OUT_ERR OUT_TODO STATE_COUNT STATE_FAILED STATE_PLAN STATE_ENDED STATE_LEGACY/;
Test::Stream::Exporter->cleanup;

sub plan   { $_[0]->[STATE]->[-1]->[STATE_PLAN]   }
sub count  { $_[0]->[STATE]->[-1]->[STATE_COUNT]  }
sub failed { $_[0]->[STATE]->[-1]->[STATE_FAILED] }
sub ended  { $_[0]->[STATE]->[-1]->[STATE_ENDED]  }
sub legacy { $_[0]->[STATE]->[-1]->[STATE_LEGACY] }

sub is_passing {
    my $self = shift;

    if (@_) {
        ($self->[STATE]->[-1]->[STATE_PASSING]) = @_;
    }

    my $current = $self->[STATE]->[-1]->[STATE_PASSING];

    my $plan = $self->[STATE]->[-1]->[STATE_PLAN];
    return $current if $self->[STATE]->[-1]->[STATE_ENDED];
    return $current unless $plan;
    return $current unless $plan->max;
    return $current if $plan->directive && $plan->directive eq 'NO PLAN';
    return $current unless $self->[STATE]->[-1]->[STATE_COUNT] > $plan->max;

    return $self->[STATE]->[-1]->[STATE_PASSING] = 0;
}

sub init {
    my $self = shift;

    $self->[PID]         = $$;
    $self->[TID]         = get_tid();
    $self->[STATE]       = [[0, 0, undef, 1]];
    $self->[USE_TAP]     = 1;
    $self->[USE_NUMBERS] = 1;
    $self->[IO_SETS]     = Test::Stream::IOSets->new;
    $self->[EVENT_ID]    = 1;
    $self->[NO_ENDING]   = 1;

    $self->use_fork if USE_THREADS;

    $self->[EXIT_ON_DISRUPTION] = 1;
}

{
    my ($root, @stack, $magic);

    END { $magic->do_magic($root) if $magic && $root && !$root->[NO_ENDING] }

    sub shared {
        my ($class) = @_;
        return $stack[-1] if @stack;

        @stack = ($root = $class->new(0));
        $root->[NO_ENDING] = 0;

        require Test::Stream::Context;
        require Test::Stream::Event::Finish;
        require Test::Stream::ExitMagic;
        require Test::Stream::ExitMagic::Context;

        $magic = Test::Stream::ExitMagic->new;

        return $root;
    }

    sub clear {
        use Carp qw/cluck/;
        $root->[NO_ENDING] = 1;
        $root  = undef;
        $magic = undef;
        @stack = ();
    }

    sub intercept_start {
        my $class = shift;
        my $new = $class->new();
        my $old = $stack[-1];
        push @stack => $new;

        $new->set_exit_on_disruption(0);
        $new->set_use_tap(0);
        $new->set_use_legacy(0);

        return ($new, $old);
    }

    sub intercept_stop {
        my $class = shift;
        my ($current) = @_;
        croak "Stream stack inconsistency" unless $current == $stack[-1];
        pop @stack;
    }
}

sub intercept {
    my $class = shift;
    my ($code) = @_;

    croak "The first argument to intercept must be a coderef"
        unless $code && ref $code && ref $code eq 'CODE';

    my ($new, $old) = $class->intercept_start();
    my ($ok, $error) = try { $code->($new, $old) };
    $class->intercept_stop($new);

    die $error unless $ok;
    return $ok;
}

sub send {
    my ($self, @events) = @_;

     return $self->fork_out(@events)
        if $self->[_USE_FORK]
        && ($$ != $self->[PID] || get_tid() != $self->[TID]);

    if ($self->[MUNGERS]) {
        @events = $_->($self, @events) for @{$self->[MUNGERS]};
    }

    push @{$self->[STATE]->[-1]->[STATE_LEGACY]} => @events if $self->[USE_LEGACY];

    for my $e (@events) {
        my $is_ok = 0;
        my $is_plan = 0;
        my $no_out = 0;
        my @sub_events;
        if ($e->isa('Test::Stream::Event::Ok')) {
            $is_ok = 1;
            $self->[STATE]->[-1]->[STATE_COUNT]++;
            if (!$e->bool) {
                $self->[STATE]->[-1]->[STATE_FAILED]++;
                $self->[STATE]->[-1]->[STATE_PASSING] = 0;
            }

            @sub_events = @{$e->diag} if $e->diag && !$self->[NO_DIAG];
        }
        elsif (!$self->[NO_HEADER] && $e->isa('Test::Stream::Event::Finish')) {
            $self->[STATE]->[-1]->[STATE_ENDED] = $e->context->snapshot;
            $is_ok = 1;
            my $plan = $self->[STATE]->[-1]->[STATE_PLAN];
            if ($e->tests_run && $plan && $plan->directive eq 'NO PLAN') {
                $plan->set_max($self->[STATE]->[-1]->[STATE_COUNT]);
                $plan->set_directive(undef);
                push @sub_events => $plan;
            }
        }
        elsif ($self->[NO_DIAG] && $e->isa('Test::Stream::Event::Diag')) {
            $no_out = 1;
        }
        elsif ($e->isa('Test::Stream::Event::Plan')) {
            $is_plan = 1;
            if($self->[NO_HEADER]) {
                $no_out = 1;
            }
            elsif(my $existing = $self->[STATE]->[-1]->[STATE_PLAN]) {
                my $directive = $existing ? $existing->directive : '';

                if ($existing && (!$directive || $directive eq 'NO PLAN')) {
                    my ($p1, $f1, $l1) = $existing->context->call;
                    my ($p2, $f2, $l2) = $e->context->call;
                    die "Tried to plan twice!\n    $f1 line $l1\n    $f2 line $l2\n";
                }
            }

            my $directive = $e->directive;
            $no_out = 1 if $directive && $directive eq 'NO PLAN';
        }

        if (!($^C || $no_out) && $self->[USE_TAP] && ($is_ok || $e->can('to_tap'))) {
            for my $se ($e, @sub_events) {
                my $num = $self->use_numbers ? $self->[STATE]->[-1]->[STATE_COUNT] : undef;
                if(my ($hid, $msg) = $se->to_tap($num)) {
                    my $enc = $se->encoding || confess "Could not find encoding!";

                    if(my $io = $self->[IO_SETS]->{$enc}->[$hid]) {
                        my $indent = $se->indent;

                        local($\, $", $,) = (undef, ' ', '');
                        $msg =~ s/^/$indent/mg unless $e->isa('Test::Stream::Event::Bail');
                        print $io $msg if $io && $msg;
                    }
                }
            }
        }

        if ($self->[LISTENERS]) {
            $_->($self, $e, @sub_events) for @{$self->[LISTENERS]};
        }

        if ($is_plan) {
            $self->[STATE]->[-1]->[STATE_PLAN] = $e;
            next   unless $e->directive;
            next   unless $e->directive eq 'SKIP';
            die $e unless $self->[EXIT_ON_DISRUPTION];
            exit 0;
        }
        elsif (!$is_ok && $e->isa('Test::Stream::Event::Bail')) {
            $self->[BAILED_OUT] = $e;
            $self->[NO_ENDING]  = 1;
            die $e unless $self->[EXIT_ON_DISRUPTION];
            exit 255;
        }
    }
}

sub push_state { push @{$_[0]->[STATE]} => [0, 0, undef, 1] }
sub pop_state  { pop  @{$_[0]->[STATE]} }

sub sub_state {
    my $self = shift;
    my ($code, @args) = @_;

    croak "sub_state takes a single coderef argument" unless $code;
    $self->push_state;
    my ($ok, $error) = try { $code->(@args) };

    die $error unless $ok;
    return $self->pop_state;
}

sub listen {
    my $self = shift;
    for my $sub (@_) {
        next unless $sub;

        croak "listen only takes coderefs for arguments, got '$sub'"
            unless ref $sub && ref $sub eq 'CODE';

        push @{$self->[LISTENERS]} => $sub;
    }
}

sub munge {
    my $self = shift;
    for my $sub (@_) {
        next unless $sub;

        croak "munge only takes coderefs for arguments, got '$sub'"
            unless ref $sub && ref $sub eq 'CODE';

        push @{$self->[MUNGERS]} => $sub;
    }
}

sub use_fork {
    require File::Temp;
    require Storable;

    $_[0]->[_USE_FORK] ||= File::Temp::tempdir(CLEANUP => 0);
    confess "Could not get a temp dir" unless $_[0]->[_USE_FORK];
    return 1;
}

sub fork_out {
    my $self = shift;

    my $tempdir = $self->[_USE_FORK];
    confess "Fork support has not been turned on!" unless $tempdir;

    my $tid = get_tid();

    for my $event (@_) {
        next unless $event;
        next if $event->isa('Test::Stream::Event::Finish');


        # First write the file, then rename it so that it is not read before it is ready.
        my $name =  $tempdir . "/$$-$tid-" . ($self->[EVENT_ID]++);
        $event->context->set_stream(undef);
        Storable::store($event, $name);
        rename($name, "$name.ready") || confess "Could not rename file '$name' -> '$name.ready'";
    }
}

sub fork_cull {
    my $self = shift;

    confess "fork_cull() can only be called from the parent process!"
        if $$ != $self->[PID];

    confess "fork_cull() can only be called from the parent thread!"
        if get_tid() != $self->[TID];

    my $tempdir = $self->[_USE_FORK];
    confess "Fork support has not been turned on!" unless $tempdir;

    opendir(my $dh, $tempdir) || croak "could not open temp dir ($tempdir)!";

    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        next unless $file =~ m/\.ready$/;

        my $obj = Storable::retrieve("$tempdir/$file");
        confess "Empty event object found '$tempdir/$file'" unless $obj;
        $obj->context->set_stream($self);

        $self->send($obj);

        if ($ENV{TEST_KEEP_TMP_DIR}) {
            rename("$tempdir/$file", "$tempdir/$file.complete")
                || confess "Could not rename file '$tempdir/$file', '$tempdir/$file.complete'";
        }
        else {
            unlink("$tempdir/$file") || die "Could not unlink file: $file";
        }
    }

    closedir($dh);
}

sub DESTROY {
    my $self = shift;

    return unless $$ == $self->pid && get_tid() == $self->tid;

    my $dir = $self->[_USE_FORK] || return;

    if ($ENV{TEST_KEEP_TMP_DIR}) {
        print STDERR "# Not removing temp dir: $dir\n";
        return;
    }

    opendir(my $dh, $dir) || confess "Could not open temp dir! ($dir)";
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        die "Unculled event! You ran tests in a child process, but never pulled them in!\n"
            if $file !~ m/\.complete$/;
        unlink("$dir/$file") || confess "Could not unlink file: '$dir/$file'";
    }
    closedir($dh);
    rmdir($dir) || warn "Could not remove temp dir ($dir)";
}

sub done_testing {
    my $self = shift;
    my ($ctx, $num) = @_;
    my $state = $self->[STATE]->[-1];

    if (my $old = $state->[STATE_ENDED]) {
        my ($p1, $f1, $l1) = $old->call;
        $ctx->ok(0, "done_testing() was already called at $f1 line $l1");
        return;
    }
    $state->[STATE_ENDED] = $ctx->snapshot;

    my $ran  = $state->[STATE_COUNT];
    my $plan = $state->[STATE_PLAN] ? $state->[STATE_PLAN]->max : 0;

    if (defined($num) && $plan && $num != $plan) {
        $ctx->ok(0, "planned to run $plan but done_testing() expects $num");
        return;
    }

    $ctx->plan($num || $plan || $ran) unless $state->[STATE_PLAN];

    if ($plan && $plan != $ran) {
        $state->[STATE_PASSING] = 0;
        return;
    }

    if ($num && $num != $ran) {
        $state->[STATE_PASSING] = 0;
        return;
    }

    unless ($ran) {
        $state->[STATE_PASSING] = 0;
        return;
    }
}

1;
