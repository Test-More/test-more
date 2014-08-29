package Test::Stream;
use strict;
use warnings;

use Carp qw/croak confess/;

use Test::Stream::IOSets;
use Test::Stream::Threads;
use Test::Stream::Util qw/try/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw{
        pid
        state passing
        listeners mungers
        no_ending
        plan bailed_out
        exit_on_disruption
        use_tap use_legacy use_fork
        io_sets
    };
    Test::Stream::ArrayBase->cleanup;
}

use constant STATE_COUNT  => 0;
use constant STATE_FAILED => 1;

use constant OUT_STD  => 0;
use constant OUT_ERR  => 1;
use constant OUT_TODO => 2;

use Test::Stream::Exporter;
exports qw/OUT_STD OUT_ERR OUT_TODO STATE_COUNT STATE_FAILED/;
Test::Stream::Exporter->cleanup;

sub init {
    my $self = shift;

    $self->[PID] ||= $$;

    $self->[STATE] ||= [[0, 0]];
    share($self->[STATE]);

    $self->[IO_SETS] ||= Test::Stream::IOSets->new;

    $self->[USE_TAP] = 1 unless defined $self->[USE_TAP];
    $self->[PASSING] = 1 unless defined $self->[PASSING];

    $self->[EXIT_ON_DISRUPTION] = 1
        unless defined $self->[EXIT_ON_DISRUPTION];
}

{
    my ($root, @stack);

    sub shared {
        my ($class) = @_;
        return $stack[-1] if @stack;
        @stack = ($root = $class->new());
        return $root;
    }

    sub clear {
        $root = undef;
        @stack = ();
    }

    sub intercept_start {
        my $class = shift;
        my $new = $class->new(@_);
        push @stack => $new;
        return $new;
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
    my ($code, @args) = @_;

    croak "The first argument to intercept must be a coderef"
        unless $code && ref $code && ref $code eq 'CODE';

    my $new = $class->intercept_start(@args);
    my ($ok, $error) = try { $code->($new) };
    $class->intercept_stop($new);

    die $error unless $ok;
    return $ok;
}

sub send {
    my ($self, @events) = @_;

    $self->fork_out(@events) if $self->[USE_FORK];

    if (@{$self->[MUNGERS]}) {
        @events = $_->($self, @events) for @{$self->[MUNGERS]};
    }

    push @{$self->[USE_LEGACY]} => @events if $self->[USE_LEGACY];

    for my $e (@events) {
        lock($self->[STATE]);

        my $is_ok = 0;
        if ($e->isa('Test::Stream::Event::Ok')) {
            $is_ok = 1;
            $self->[STATE]->[-1]->[STATE_COUNT]++;
            if (!$e->bool) {
                $self->[STATE]->[-1]->[STATE_FAILED]++;
                $self->[PASSING] = 0;
            }
        }

        if (!$^C && $self->[USE_TAP] && $e->can('to_tap')) {
            if(my ($hid, $msg) = $e->to_tap($self->[STATE]->[-1]->[STATE_COUNT])) {
                my $enc = $e->encoding || confess "Could not find encoding!";

                if(my $io = $self->[IO_SETS]->{$enc}->[$hid]) {
                    my $indent = $e->indent;

                    local($\, $", $,) = (undef, ' ', '');
                    $msg =~ s/^/$indent/mg;
                    print $io $msg if $io && $msg;
                }
            }
        }

        $_->($self, $e) for @{$self->[LISTENERS]};

        if (!$is_ok) {
            if ($e->isa('Test::Stream::Event::Plan')) {
                $self->[PLAN] = $e;
                next unless $e->directive;
                next unless $e->directive eq 'SKIP';
                die $e unless $self->[EXIT_ON_DISRUPTION];
                exit 0;
            }
            elsif ($e->isa('Test::Stream::Event::Bail')) {
                die $e unless $self->[EXIT_ON_DISRUPTION];
                exit 255;
            }
        }
    }
}

sub push_state { push @{$_[0]->[STATE]} => share([0, 0]) }
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

1;
