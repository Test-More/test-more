package Test::Stream::Workflow;
use strict;
use warnings;

use Scalar::Util qw/reftype blessed/;
use Carp qw/confess croak/;

use Test::Stream::Block;
use Test::Stream::Sync;

use Test::Stream::Workflow::Meta;
use Test::Stream::Workflow::Unit;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/try/;

use Test::Stream::Exporter;
default_exports qw{
    workflow_build
    workflow_current
    workflow_meta
    workflow_runner
    workflow_runner_args
    workflow_var
    workflow_run
};

exports qw{
    new_proto_unit
    group_builder
    die_at_caller
    gen_unit_builder
};

export import => sub {
    my $class = shift;
    my ($pkg, $file, $line) = caller;

    Test::Stream::Exporter::export_from($class, $pkg, \@_);

    # This is a no-op if it has already been done.
    Test::Stream::Workflow::Meta->build($pkg, $file, $line, 'EOF');
};

export unimport => sub {
    my $caller = caller;
    my $meta = Test::Stream::Workflow::Meta->get($caller);
    $meta->set_autorun(0);
};
no Test::Stream::Exporter;

my @BUILD;

sub workflow_build       { @BUILD ? $BUILD[-1] : undef }
sub workflow_current     { _current(caller)            }
sub workflow_meta        { Test::Stream::Workflow::Meta->get(scalar caller) }
sub workflow_run         { Test::Stream::Workflow::Meta->get(scalar caller)->run(@_) }
sub workflow_runner      { Test::Stream::Workflow::Meta->get(scalar caller)->set_runner(@_) }
sub workflow_runner_args { Test::Stream::Workflow::Meta->get(scalar caller)->set_runner_args(@_) }

sub workflow_var {
    my $vars = Test::Stream::Workflow::Runner->VARS;
    confess "No VARS! VAR() should only be called inside a unit sub"
        unless $vars;

    my $name = shift;
    ($vars->{$name}) = @_ if @_;
    return $vars->{$name};
};

sub _current {
    my ($caller) = @_;

    return $BUILD[-1] if @BUILD;
    my $spec_meta = Test::Stream::Workflow::Meta->get($caller) || return;
    return $spec_meta->unit;
}

sub die_at_caller {
    my ($caller, $msg) = @_;
    die "$msg at $caller->[1] line $caller->[2].\n";
}

sub new_proto_unit {
    my %params = @_;
    my $caller = $params{caller} || [caller($params{level} || 1)];
    my $args   = $params{args};

    die_at_caller $caller => "Too many arguments for $caller->[3]"
        if @$args > 3;

    my $name = shift @$args;
    my $code = pop @$args;
    my $meta = shift @$args;

    die_at_caller $caller => "The first argument to $caller->[3] (name) is required"
        unless $name;
    die_at_caller $caller => "The first argument to $caller->[3] (name) may not be a reference"
        if ref $name;
    die_at_caller $caller => "The final argument to $caller->[3] (code) is required"
        unless $code;
    die_at_caller $caller => "The final argument to $caller->[3] (code) must be a sub reference"
        unless reftype $code eq 'CODE';
    die_at_caller $caller => "The middle argument to $caller->[3] (meta) must be a hash reference when present"
        if $meta && reftype($meta) ne 'HASH';

    my $block = Test::Stream::Block->new(
        name    => $name,
        coderef => $code,
        caller  => $caller,
    );

    my $unit = Test::Stream::Workflow::Unit->new(
        name       => $name,
        meta       => $meta,
        start_line => $block->start_line,
        end_line   => $block->end_line,
        file       => $block->file,
        package    => $caller->[0],

        $params{set_primary} ? (primary => $code) : (),

        $params{unit} ? (%{$params{unit}}) : (),
    );

    return ($unit, $block, $caller);
}

sub group_builder {
    my ($unit, $block, $caller) = new_proto_unit(
        args => \@_,
        unit => { type => 'group' },
    );

    push @BUILD => $unit;
    my ($ok, $err) = try {
        $block->coderef->($unit);
        1; # To force the previous statement to be in void context
    };
    pop @BUILD;
    die $err unless $ok;

    $unit->do_post;

    # Correct for multi-line subs as first statements
    my $start = $unit->start_line;
    for my $stash (qw/modify primary buildup teardown/) {
        my $list = $unit->$stash || next;
        my $top  = $list->[0]    || next;
        my $line = $top->start_line;
        if ($line < $start) {
            $start = $line;
            $start -= 1 if $start < $unit->end_line;
        }
    }
    $unit->set_start_line($start);

    return $unit if defined wantarray;

    my $current = _current($caller->[0])
        || confess "Could not find the current build!";

    $current->add_primary($unit);
}

{
    my $pkg = __PACKAGE__;
    my %ALLOWED_STASHES = map {$_ => 1} qw{
        primary
        modify
        buildup
        teardown
        buildup+teardown
    };

    my %CALLBACKS = (
        simple => sub {
            my ($current, $unit, @stashes) = @_;
            $current->$_($unit) for map {"add_$_"} @stashes;
        },
        modifiers => sub {
            my ($current, $unit, @stashes) = @_;
            $current->add_post(sub {
                my $modify = $current->modify || return;
                for my $mod (@$modify) {
                    $mod->$_($unit) for map {"add_$_"} @stashes;
                }
            });
        },
        primaries => sub {
            my ($current, $unit, @stashes) = @_;
            $current->set_stash({}) unless $current->stash;
            my $stash = $current->stash;
            unless($stash->{$pkg}) {
                $stash->{$pkg} = {};
                $current->add_post(sub {
                    my $stuff = delete $stash->{$pkg};

                    my $modify   = $stuff->{modify};
                    my $buildup  = $stuff->{buildup};
                    my $primary  = $stuff->{primary};
                    my $teardown = $stuff->{teardown};

                    my @search = ($current);
                    while (my $it = shift @search) {
                        if ($it->type eq 'group') {
                            my $prim = $it->primary || next;
                            push @search => @$prim;
                            next;
                        }

                        unshift @{$it->{modify}}   => @$modify   if $modify;
                        unshift @{$it->{buildup}}  => @$buildup  if $buildup;
                        push    @{$it->{primary}}  => @$primary  if $primary;
                        push    @{$it->{teardown}} => @$teardown if $teardown;
                    }
                });
            }

            push @{$stash->{$pkg}->{$_}} => $unit for @stashes;
        },
    );

    sub gen_unit_builder {
        my ($callback, @stashes) = @_;
        croak "Not enough arguments to gen_unit_builder()"
            unless @stashes;

        my $reftype = reftype($callback) || "";
        my $cb_sub = $reftype eq 'CODE' ? $callback : $CALLBACKS{$callback};
        croak "'$callback' is not a valid callback"
            unless $cb_sub;

        my $wrap = @stashes > 1 ? 1 : 0;
        my $check = join '+', sort @stashes;
        croak "'$check' is not a valid stash"
            unless $ALLOWED_STASHES{$check};

        return sub {
            my ($unit, $block, $caller) = new_proto_unit(
                set_primary => 1,
                args        => \@_,
                unit        => {type => 'single', wrap => $wrap},
            );

            confess "$caller->[3] must only be called in a void context"
                if defined wantarray;

            my $current = _current($caller->[0])
                || confess "Could not find the current build!";

            $cb_sub->($current, $unit, @stashes);
        }
    }
}

1;
