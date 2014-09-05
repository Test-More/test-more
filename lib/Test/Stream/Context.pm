package Test::Stream::Context;
use strict;
use warnings;

use Scalar::Util qw/blessed weaken/;
use Carp qw/confess/;

use Test::Stream;
use Test::Stream::Event();
use Test::Stream::Util qw/try/;
use Test::Stream::Meta qw/init_tester/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/frame stream encoding in_todo todo modern depth pid skip/;
    Test::Stream::ArrayBase->cleanup;
}

use Test::Stream::Exporter qw/import export_to exports/;
exports qw/context/;
Test::Stream::Exporter->cleanup();

our $DEPTH = 0;
our $CURRENT;

sub init {
    $_[0]->[FRAME]    ||= _find_context(1);                # +1 for call to init
    $_[0]->[STREAM]   ||= Test::Stream->shared;
    $_[0]->[ENCODING] ||= 'legacy';
    $_[0]->[PID]      ||= $$;
}

sub peek { $CURRENT }

sub context {
    # If the context has already been initialized we simply return it, we
    # ignore any additional parameters as they no longer matter. The first
    # thing to ask for a context wins, anything context aware that is called
    # later MUST expect that it can get a context found by something down the
    # stack.
    return $CURRENT if $CURRENT;

    my ($level) = @_;
    my $call = _find_context($level); # the only arg is an integer to add to the caller level
    my $pkg  = $call->[0];

    # init_tester returns ther meta if found, otherwise it creates it and then
    # adds it.
    my $meta = init_tester($pkg);

    # Check if $TODO is set in the package, if not check if Test::Builder is
    # loaded, and if so if it has Todo set. We check the element directly for
    # performance.
    my $todo;
    {
        no strict 'refs'; no warnings 'once';
        $todo = $meta->[Test::Stream::Meta::TODO] || ${"$pkg\::TODO"} || undef;
    };
    my $in_todo = defined $todo;

    my $ctx = bless(
        [
            $call,
            $meta->[Test::Stream::Meta::STREAM]   || Test::Stream->shared,
            $meta->[Test::Stream::Meta::ENCODING] || 'legacy',
            $in_todo,
            $todo,
            $meta->[Test::Stream::Meta::MODERN]   || 0,
            $DEPTH,
            $$,
            undef,
        ],
        __PACKAGE__
    );

    $CURRENT = $ctx;
    weaken($CURRENT);
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
    confess "Level: $level" unless $package;
    return [$package, $file, $line, $subname];
}

sub done_testing {
    $_[0]->stream->done_testing(@_);
}

sub alert {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    warn "$msg at $call[1] line $call[2]\n";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    die "$msg at $call[1] line $call[2]\n";
}

sub call { @{$_[0]->[FRAME]} }

sub package { $_[0]->[FRAME]->[0] }
sub file    { $_[0]->[FRAME]->[1] }
sub line    { $_[0]->[FRAME]->[2] }
sub subname { $_[0]->[FRAME]->[3] }

sub snapshot {
    return bless [@{$_[0]}], blessed($_[0]);
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
        local $CURRENT = $clone;
        $code->($self, $clone);
    };

    die $error unless $ok;
}

sub nest {
    my $self = shift;
    my ($code, @args) = @_;

    my $pass;

    $self->child('push');

    my ($ok, $error) = try {
        local $DEPTH = $DEPTH + 1;
        local $CURRENT = undef;
        $self->stream->push_state;
        $code->(@args);

        use Data::Dumper;
        unless ($self->stream->ended) {
            my $ctx = $self->snapshot;
            $ctx->[DEPTH] = $DEPTH;
            $ctx->done_testing;
        }

        $pass = $self->stream->is_passing;

        $self->stream->pop_state;
    };

    $self->child('pop');

    die $error unless $ok;

    return $pass;
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
        my @call = caller(0);
        my $e = $pkg->new($self->snapshot, [@call[0 .. 4]], @_);
        $self->stream->send($e);
        return $e;
    };
}

our $AUTOLOAD;
sub AUTOLOAD {
    my $class = blessed($_[0]) || $_[0];

    my $name = $AUTOLOAD;
    $name =~ s/^.*:://g;

    my $module = 'Test/Stream/Event/' . ucfirst(lc($name)) . '.pm';
    try { require $module };

    my $sub = $class->can($name);
    goto &$sub if $sub;

    my ($pkg, $file, $line) = caller;

    die qq{Can't locate object method "$name" via package "$class" at $file line $line.\n};
}

1;
