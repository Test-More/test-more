package Test::Provider::Context;
use strict;
use warnings;

use Scalar::Util();

use Test::Stream::Util qw/try/;
use Test::Provider::Meta qw/init_tester/;

# Load all the events to generate event methods
use Test::Stream;
use base 'Test::Stream::Context';
use Test::Stream::Event::Bail;
use Test::Stream::Event::Child;
use Test::Stream::Event::Diag;
use Test::Stream::Event::Finish;
use Test::Stream::Event::Note;
use Test::Stream::Event::Ok;
use Test::Stream::Event::Plan;

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
        $todo = $meta->[Test::Provider::Meta::TODO] || ${"$pkg\::TODO"} || ($Test::Builder::Test ? $Test::Builder::Test->{Todo} : undef);
    };
    my $in_todo = defined $todo;

    my $ctx = bless(
        [
            $call,
            $meta->[Test::Provider::Meta::STREAM]   || Test::Stream->shared,
            $meta->[Test::Provider::Meta::ENCODING] || 'legacy',
            $in_todo,
            $todo,
            $meta->[Test::Provider::Meta::MODERN]   || 0,
            $DEPTH,
            $$,
            undef,
        ],
        __PACKAGE__
    );

    $CURRENT = $ctx;
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

sub package { $_[0]->[FRAME]->[0] }
sub file    { $_[0]->[FRAME]->[1] }
sub line    { $_[0]->[FRAME]->[2] }
sub subname { $_[0]->[FRAME]->[3] }

sub snapshot {
    return bless [@{$_[0]}], Scalar::Util::blessed($_[0]);
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
        no warnings 'once'; # PITA
        local $Test::Buider::Level = 1;
        $self->stream->push_state;
        $code->(@args);
        $pass = $self->stream->is_passing;
        $self->stream->pop_state;
    };

    $self->child('pop');

    die $error unless $ok;

    return $pass;
}

1;
