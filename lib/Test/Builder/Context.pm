package Test::Builder::Context;
use strict;
use warnings;
no warnings 'once'; # PITA

use Scalar::Util();
use Test::Builder::Util qw/is_tester init_tester/;

require Test::Builder::Event::Bail;
require Test::Builder::Event::Child;
require Test::Builder::Event::Diag;
require Test::Builder::Event::Finish;
require Test::Builder::Event::Note;
require Test::Builder::Event::Ok;
require Test::Builder::Event::Plan;

# Performance has been a real issue with this, so we are using an array under
# the hood. This is NOT premature optimization, it is optimization in response
# to complaints. When the new context code was first written it increased the
# perl test suite time 3x, which is not acceptable. These are the indexes into
# the array.
use constant FRAME    => 0;
use constant STREAM   => 1;
use constant ENCODING => 2;
use constant IN_TODO  => 3;
use constant TODO     => 4;
use constant DEPTH    => 5;
use constant PID      => 6;
use constant SKIP     => 7;

our $DEPTH = 0;
our $CURRENT;

sub context {
    # If the context has already been initialized we simply return it, we
    # ignore any additional parameters as they no longer matter. The first
    # thing to ask for a context wins, anything context aware that is called
    # later MUST expect that it can get a context found by something down the
    # stack.
    return $$CURRENT if $CURRENT;

    my $call = _find_context(@_); # the only arg is an integer to add to the caller level
    my $pkg  = $call->[0];

    # init_tester returns ther meta if found, otherwise it creates it and then
    # adds it.
    my $meta = init_tester($pkg);

    # Check if $TODO is set in the package, if not check if Test::Builder is
    # loaded, and if so if it has Todo set. We check the element directly for
    # performance.
    my $todo = ${*{$meta->{todo}}{SCALAR}} || $Test::Builder::Test ? $Test::Builder::Test->{Todo} : undef;
    my $in_todo = defined $todo;

    my $ctx = bless(
        [
            $call,
            $meta->{stream}   || Test::Builder::Stream->shared,
            $meta->{encoding} || 'legacy',
            $in_todo,
            $todo,
            $DEPTH,
            $$,
            undef
        ],
        __PACKAGE__
    );

    $CURRENT = \$ctx;
    Scalar::Util::weaken($CURRENT);
    return $ctx;
}

sub _find_context {
    my ($add) = @_;
    $add ||= 0;

    # 0 - call to us
    # 1 - call to fetch
    # 2 - call to tool that fetched
    my $level = 2 + $add;
    my ($package, $file, $line, $subname) = caller($level);
    return [$package, $file, $line, $subname];
}

sub call { @{$_[0]->[FRAME]} }

sub frame    { $_[0]->[FRAME]    }
sub stream   { $_[0]->[STREAM]   }
sub encoding { $_[0]->[ENCODING] }
sub in_todo  { $_[0]->[IN_TODO]  }
sub todo     { $_[0]->[TODO]     }
sub depth    { $_[0]->[DEPTH]    }
sub pid      { $_[0]->[PID]      }

sub skip {
    my $self = shift;
    return $self->[SKIP] unless @_;

    my ($reason, $code) = @_;
    local $self->[SKIP] = $reason;
    $code->($self);
}

sub set_depth {
    my $self = shift;
    ($self->[DEPTH]) = @_ if @_;
}

sub set_encoding {
    my $self = shift;
    ($self->[ENCODING]) = @_ if @_;
}

sub set_todo {
    my $self = shift;
    if (@_) {
        ($self->[TODO]) = @_;
        $self->[IN_TODO] = defined $self->[TODO];
    }
}

sub send {
    my $self = shift;
    $self->[STREAM]->send(@_);
}

sub stage {
    my $self = shift;
    my ($code) = @_;

    my ($ok, $error) = try {
        my $clone = bless [@$self], __PACKAGE__;
        $clone->[FRAME] = [$self->call];
        local $CURRENT = \$clone;
        $code->($self, $clone);
    };

    die $error unless $ok;
}

sub nest {
    my $self = shift;
    my ($code, @args) = @_;

    $self->child('push');

    my ($ok, $error) = try {
        local $DEPTH = $DEPTH + 1;
        local $CURRENT = undef;
        local $Test::Builder::Level = 1;
        $code->(@args);
    };

    $self->child('pop');

    die $error unless $ok;
}

# Methods for firing off events.
BEGIN {
    for my $event (qw/Bail Child Diag Finish Note Ok Plan/) {
        my $name = lc($event);
        my $pkg = "Test::Builder::Event::$event";

        no strict 'refs';
        *$name = sub {
            use strict 'refs';
            my $self = shift;
            my @call = caller;
            my $e = $pkg->new($self, [$call[0..4]], @_);
            $self->[STREAM]->send($e);
            return $e;
        };
    }
}

1;
