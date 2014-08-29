package Test::Stream::Context;
use strict;
use warnings;
no warnings 'once'; # PITA

use Scalar::Util();
use Carp qw/confess/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/frame stream encoding in_todo todo depth pid skip/;
    Test::Stream::ArrayBase->cleanup;
}

use Test::Stream::Util qw/is_tester init_tester/;
use Test::Stream;

our $DEPTH = 0;
our $CURRENT;

# now load all the default event types to make sure their methods get
# registered.
require Test::Stream::Event::Bail;
require Test::Stream::Event::Child;
require Test::Stream::Event::Diag;
require Test::Stream::Event::Finish;
require Test::Stream::Event::Note;
require Test::Stream::Event::Ok;
require Test::Stream::Event::Plan;

sub init {
    $_[0]->[FRAME]    ||= _find_context(1);                # +1 for call to init
    $_[0]->[STREAM]   ||= Test::Stream->shared;
    $_[0]->[ENCODING] ||= 'legacy';
    $_[0]->[PID]      ||= $$;
}

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
    my $todo = ${*{$meta->{todo}}{SCALAR}} || $Test::Stream::Test ? $Test::Stream::Test->{Todo} : undef;
    my $in_todo = defined $todo;

    my $ctx = bless(
        [
            $call,
            $meta->{stream}   || Test::Stream->shared,
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

    # 0 - call to find_context
    # 1 - call to context/new
    # 2 - call to tool
    my $level = 2 + $add;
    my ($package, $file, $line, $subname) = caller($level);
    return [$package, $file, $line, $subname];
}

sub call { @{$_[0]->[FRAME]} }

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
        local $Test::Stream::Level = 1;
        $code->(@args);
    };

    $self->child('pop');

    die $error unless $ok;
}

sub register_event {
    my $class = shift;
    my ($pkg) = @_;
    my $name = lc($pkg);
    $name =~ s/^.*:://g;

    confess "Method '$name' is already defined, event '$pkg' cannot get a context method!"
        if $class->can($name);

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

1;
