package Test::Stream::Context;
use strict;
use warnings;

use Scalar::Util qw/blessed weaken/;

use Test::Stream::Carp qw/confess/;

use Test::Stream;
use Test::Stream::Threads;
use Test::Stream::Event();
use Test::Stream::Util qw/try/;
use Test::Stream::Meta qw/init_tester is_tester/;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/frame stream encoding in_todo todo modern pid skip diag_todo provider/;
    Test::Stream::ArrayBase->cleanup;
}

use Test::Stream::Exporter qw/import export_to exports/;
exports qw/context/;
Test::Stream::Exporter->cleanup();

{
    no warnings 'once';
    $Test::Builder::Level ||= 1;
}

my $CURRENT;

sub init {
    $_[0]->[FRAME]    ||= _find_context(1);                # +1 for call to init
    $_[0]->[STREAM]   ||= Test::Stream->shared;
    $_[0]->[ENCODING] ||= 'legacy';
    $_[0]->[PID]      ||= $$;
}

sub peek  { $CURRENT }
sub clear { $CURRENT = undef }

sub set {
    $CURRENT = pop;
    weaken($CURRENT);
}

sub context {
    my ($level, $stream) = @_;
    # If the context has already been initialized we simply return it, we
    # ignore any additional parameters as they no longer matter. The first
    # thing to ask for a context wins, anything context aware that is called
    # later MUST expect that it can get a context found by something down the
    # stack.
    if ($CURRENT) {
        return $CURRENT unless $stream;
        return $CURRENT if $stream == $CURRENT->[STREAM];
    }

    my $call = _find_context($level);

    $call = _find_context_harder() unless $call && is_tester($call->[0]);
    my $pkg  = $call->[0];

    my $meta = is_tester($pkg);

    # Check if $TODO is set in the package, if not check if Test::Builder is
    # loaded, and if so if it has Todo set. We check the element directly for
    # performance.
    my ($todo, $in_todo);
    {
        no strict 'refs';
        no warnings 'once';
        if ($todo = $meta->[Test::Stream::Meta::TODO]) {
            $in_todo = 1;
        }
        elsif ($todo = ${"$pkg\::TODO"}) {
            $in_todo = 1;
        }
        elsif ($Test::Builder::Test && defined $Test::Builder::Test->{Todo}) {
            $todo    = $Test::Builder::Test->{Todo};
            $in_todo = 1;
        }
        else {
            $in_todo = 0;
        }
    };

    my ($ppkg, $pname);
    if(my @provider = caller(1)) {
        ($ppkg, $pname) = ($provider[3] =~ m/^(.*)::([^:]+)$/);
    }

    $stream ||= $meta->[Test::Stream::Meta::STREAM] || Test::Stream->shared;
    if ((USE_THREADS || $stream->_use_fork) && ($stream->pid == $$ && $stream->tid == get_tid())) {
        $stream->fork_cull();
    }

    my $ctx = bless(
        [
            $call,
            $stream,
            $meta->[Test::Stream::Meta::ENCODING] || 'legacy',
            $in_todo,
            $todo,
            $meta->[Test::Stream::Meta::MODERN]   || 0,
            $$,
            undef,
            $in_todo,
            [$ppkg, $pname]
        ],
        __PACKAGE__
    );

    return $ctx if $CURRENT;

    $CURRENT = $ctx;
    weaken($CURRENT);
    return $ctx;
}

sub _find_context {
    my ($add) = @_;

    $add ||= 0;
    my $tb = $Test::Builder::Level - 1;

    # 0 - call to find_context
    # 1 - call to context/new
    # 2 - call to tool
    my $level = 2 + $add + $tb;
    my ($package, $file, $line, $subname) = caller($level);

    return unless $package;

    while ($package eq 'Test::Builder') {
        ($package, $file, $line, $subname) = caller(++$level);
    }

    return unless $package;

    return [$package, $file, $line, $subname];
}

sub _find_context_harder {
    my $level = 0;
    while(1) {
        my ($pkg, $file, $line, $subname) = caller($level++);
        last unless $pkg;
        return [$pkg, $file, $line, $subname] if is_tester($pkg);
    }

    # Find, find a .t file!
    $level = 0;
    while(1) {
        my ($pkg, $file, $line, $subname) = caller($level++);
        last unless $pkg;
        if ($file eq $0 && $file =~ m/\.t$/) {
            init_tester($pkg);
            return [$pkg, $file, $line, $subname];
        }
    }

    # Final fallback, package main (If it is in the stack)
    $level = 0;
    while(1) {
        my ($pkg, $file, $line, $subname) = caller($level++);
        last unless $pkg;
        next unless $pkg eq 'main';

        init_tester($pkg);
        return [$pkg, $file, $line, $subname];
    }

    # Give up!
    confess "Could not find context! No tester in the stack!";
}

sub done_testing {
    $_[0]->stream->done_testing(@_);
}

sub alert {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    warn "$msg at $call[1] line $call[2].\n";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    $CURRENT = undef if $CURRENT = $self;

    die "$msg at $call[1] line $call[2].\n";
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

sub register_event {
    my $class = shift;
    my ($pkg) = @_;
    my $name = lc($pkg);
    $name =~ s/^.*:://g;

    confess "Method '$name' is already defined, event '$pkg' cannot get a context method!"
        if $class->can($name);

    # Use a string eval so that we get a names sub instead of __ANON__
    local ($@, $!);
    eval qq|
        sub $name {
            my \$self = shift;
            my \@call = caller(0);
            my \$e = \$pkg->new(\$self->snapshot, [\@call[0 .. 4]], 0, \@_);
            return \$self->stream->send(\$e);
        };
        1;
    | || die $@;
}

sub hide_todo {
    my $self = shift;
    no strict 'refs';
    no warnings 'once';

    my $pkg = $self->[FRAME]->[0];
    my $meta = is_tester($pkg);

    my $found = {
        TB   => $Test::Builder::Test ? $Test::Builder::Test->{Todo} : undef,
        META => $meta->[Test::Stream::Meta::TODO],
        PKG  => ${"$pkg\::TODO"},
    };

    $Test::Builder::Test->{Todo} = undef;
    $meta->[Test::Stream::Meta::TODO] = undef;
    ${"$pkg\::TODO"} = undef;

    return $found;
}

sub restore_todo {
    my $self = shift;
    my ($found) = @_;
    no strict 'refs';
    no warnings 'once';

    my $pkg = $self->[FRAME]->[0];
    my $meta = is_tester($pkg);

    $Test::Builder::Test->{Todo} = $found->{TB};
    $meta->[Test::Stream::Meta::TODO] = $found->{META};
    ${"$pkg\::TODO"} = $found->{PKG};

    my $found2 = {
        TB   => $Test::Builder::Test ? $Test::Builder::Test->{Todo} : undef,
        META => $meta->[Test::Stream::Meta::TODO] || undef,
        PKG  => ${"$pkg\::TODO"} || undef,
    };

    for my $k (qw/TB META PKG/) {
        no warnings 'uninitialized';
        next if "$found->{$k}" eq "$found2->{$k}";
        die "Mismatch! $k:\t$found->{$k}\n\t$found2->{$k}\n"
    }

    return;
}

sub DESTROY { 1 }

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
