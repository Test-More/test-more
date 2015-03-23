package Test::Stream::Context;
use strict;
use warnings;

use Scalar::Util qw/blessed weaken/;

use Test::Stream::Carp qw/confess/;

use Test::Stream::Threads;
use Test::Stream::Event();
use Test::Stream::Util qw/try translate_filename/;
use Test::Stream::Meta qw/init_tester is_tester/;

use Test::Stream::HashBase(
    accessors => [qw/frame stream encoding in_todo todo modern pid skip diag_todo provider monkeypatch_stash/],
);

use Test::Stream::Exporter qw/import export_to default_exports exports/;
default_exports qw/context/;
exports qw/inspect_todo/;
Test::Stream::Exporter->cleanup();

{
    no warnings 'once';
    $Test::Builder::Level ||= 1;
}

my @TODO;
my $CURRENT;

sub from_end_block { 0 };

sub init {
    $_[0]->{+FRAME}    ||= _find_context(1);                # +1 for call to init
    $_[0]->{+STREAM}   ||= Test::Stream->shared;
    $_[0]->{+ENCODING} ||= 'legacy';
    $_[0]->{+PID}      ||= $$;
}

sub peek  { $CURRENT }
sub clear { $CURRENT = undef }

sub push_todo { push @TODO => pop @_ }
sub pop_todo  { pop  @TODO           }
sub peek_todo { @TODO ? $TODO[-1] : undef }

sub set {
    $CURRENT = pop;
    weaken($CURRENT);
}

my $WARNED;
sub context {
    my ($level, $stream) = @_;
    # If the context has already been initialized we simply return it, we
    # ignore any additional parameters as they no longer matter. The first
    # thing to ask for a context wins, anything context aware that is called
    # later MUST expect that it can get a context found by something down the
    # stack.
    if ($CURRENT) {
        return $CURRENT unless $stream;
        return $CURRENT if $stream == $CURRENT->{+STREAM};
    }

    my $call = _find_context($level);
    $call = _find_context_harder() unless $call;
    my $pkg  = $call->[0];

    my $meta = is_tester($pkg) || _find_tester();

    # Check if $TODO is set in the package, if not check if Test::Builder is
    # loaded, and if so if it has Todo set. We check the element directly for
    # performance.
    my ($todo, $in_todo);
    {
        my $todo_pkg = $meta->{Test::Stream::Meta::PACKAGE};
        no strict 'refs';
        no warnings 'once';
        if (@TODO) {
            $todo = $TODO[-1];
            $in_todo = 1;
        }
        elsif ($todo = $meta->{Test::Stream::Meta::TODO}) {
            $in_todo = 1;
        }
        elsif ($todo = ${"$pkg\::TODO"}) {
            $in_todo = 1;
        }
        elsif ($todo = ${"$todo_pkg\::TODO"}) {
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

    # Uh-Oh! someone has replaced the singleton, that means they probably want
    # everything to go through them... We can't do a whole lot about that, but
    # we will use the singletons stream which should catch most use-cases.
    if ($Test::Builder::_ORIG_Test && $Test::Builder::_ORIG_Test != $Test::Builder::Test) {
        $stream ||= $Test::Builder::Test->{stream};

        my $warn = $meta->{Test::Stream::Meta::MODERN}
                && !$WARNED++;

        warn <<"        EOT" if $warn;

    *******************************************************************************
    Something replaced the singleton \$Test::Builder::Test.

    The Test::Builder singleton is no longer the central place for all test
    events. Please look at Test::Stream, and Test::Stream->intercept() to
    accomplish the type of thing that was once done with the singleton.

    All attempts have been made to preserve compatability with older modules,
    but if you experience broken behavior you may need to update your code. If
    updating your code is not an option you will need to downgrade to a
    Test::More prior to version 1.301001. Patches that restore compatability
    without breaking necessary Test::Stream functionality will be gladly
    accepted.
    *******************************************************************************
        EOT
    }

    $stream ||= $meta->{Test::Stream::Meta::STREAM} || Test::Stream->shared || confess "No Stream!?";
    if ((USE_THREADS || $stream->_use_fork) && ($stream->pid == $$ && $stream->tid == get_tid())) {
        $stream->fork_cull();
    }

    my $encoding = $meta->{Test::Stream::Meta::ENCODING} || 'legacy';
    $call->[1] = translate_filename($encoding => $call->[1]) if $encoding ne 'legacy';

    my $ctx = bless(
        {
            FRAME()     => $call,
            STREAM()    => $stream,
            ENCODING()  => $encoding,
            IN_TODO()   => $in_todo,
            TODO()      => $todo,
            MODERN()    => $meta->{Test::Stream::Meta::MODERN} || 0,
            PID()       => $$,
            SKIP()      => undef,
            DIAG_TODO() => $in_todo,
            PROVIDER()  => [$ppkg, $pname]
        },
        __PACKAGE__
    );

    weaken($ctx->{+STREAM});

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

    if ($package) {
        while ($package eq 'Test::Builder') {
            ($package, $file, $line, $subname) = caller(++$level);
        }
    }
    else {
        while (!$package) {
            ($package, $file, $line, $subname) = caller(--$level);
        }
    }

    return unless $package;

    return [$package, $file, $line, $subname];
}

sub _find_context_harder {
    my $level = 0;
    my $fallback;
    while(1) {
        my ($pkg, $file, $line, $subname) = caller($level++);
        $fallback ||= [$pkg, $file, $line, $subname] if $subname =~ m/::END$/;
        next if $pkg =~ m/^Test::(Stream|Builder|More|Simple)(::.*)?$/;
        return [$pkg, $file, $line, $subname];
    }

    return $fallback if $fallback;
    return [ '<UNKNOWN>', '<UNKNOWN>', 0, '<UNKNOWN>' ];
}

sub _find_tester {
    my $level = 2;
    while(1) {
        my $pkg = caller($level++);
        last unless $pkg;
        my $meta = is_tester($pkg) || next;
        return $meta;
    }

    # find a .t file!
    $level = 0;
    while(1) {
        my ($pkg, $file) = caller($level++);
        last unless $pkg;
        if ($file eq $0 && $file =~ m/\.t$/) {
            return init_tester($pkg);
        }
    }

    return init_tester('main');
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

sub call { @{$_[0]->{+FRAME}} }

sub package { $_[0]->{+FRAME}->[0] }
sub file    { $_[0]->{+FRAME}->[1] }
sub line    { $_[0]->{+FRAME}->[2] }
sub subname { $_[0]->{+FRAME}->[3] }

sub snapshot {
    return bless {%{$_[0]}}, blessed($_[0]);
}

sub send {
    my $self = shift;
    $self->{+STREAM}->send(@_);
}

sub subtest_start {
    my $self = shift;
    my ($name, %params) = @_;

    $params{parent_todo} ||= $self->in_todo;

    $self->clear;
    my $todo = $self->hide_todo;

    my $st = $self->stream->subtest_start($name, todo_stash => $todo, %params);
    return $st;
}

sub subtest_stop {
    my $self = shift;
    my ($name) = @_;

    my $st = $self->stream->subtest_stop($name);

    $self->set;
    $self->restore_todo($st->{todo_stash});

    return $st;
}

sub send_event {
    my $self  = shift;
    my $event = shift;
    my @call  = caller(0);

    # Uhg.. support legacy monkeypatching
    # If this is still here in 2020 I will be a sad panda.
    return $self->_wind_event($event, @_)
        if $INC{'Test/Builder.pm'}
        && $Test::Builder::MonkeyPatching::EVENTS{$event}
        && $Test::Builder::ORIG{lc($event)} != Test::Builder->can(lc($event));

    my $encoding = $self->{+ENCODING};
    $call[1] = translate_filename($encoding => $call[1]) if $encoding ne 'legacy';

    my $pkg = $self->_parse_event($event);

    my $e = $pkg->new(
        context    => $self->snapshot,
        created    => [@call[0 .. 4]],
        in_subtest => 0,
        @_,
    );

    return $self->stream->send($e);
}

sub _wind_event {
    my $self  = shift;
    my $event = shift;
    my %args  = @_;

    my @ordered;

    if ($event eq 'Plan') {
        my $max = $args{max};
        my $dir = $args{directive};
        my $msg = $args{reason};

        $dir ||= 'tests';
        $dir = 'skip_all' if $dir eq 'SKIP';
        $dir = 'no_plan'  if $dir eq 'NO PLAN';

        @ordered = ($dir, $max || $msg || ());
    }
    else {
        my $fields = $Test::Builder::MonkeyPatching::EVENTS{$event};
        push @{$self->{+MONKEYPATCH_STASH}} => \%args;
        @ordered = @args{@$fields};
    }

    my $meth = lc($event);

    my $out = Test::Builder->new->$meth(@ordered);
    return $out;
}

sub _unwind_event {
    my $self  = shift;
    my $event = shift;
    my @call  = caller(0);
    my $stash = pop @{$self->{+MONKEYPATCH_STASH}} || {};

    my $encoding = $self->{+ENCODING};
    $call[1] = translate_filename($encoding => $call[1]) if $encoding ne 'legacy';

    my $pkg = $self->_parse_event($event);

    my $e = $pkg->new(
        context    => $self->snapshot,
        created    => [@call[0 .. 4]],
        in_subtest => 0,
        %$stash,
        @_,
    );

    return $self->stream->send($e);
}

sub build_event {
    my $self  = shift;
    my $event = shift;
    my @call  = caller(0);

    my $encoding = $self->{+ENCODING};
    $call[1] = translate_filename($encoding => $call[1]) if $encoding ne 'legacy';

    my $pkg = $self->_parse_event($event);

    my $e = $pkg->new(
        context    => $self->snapshot,
        created    => [@call[0 .. 4]],
        in_subtest => 0,
        @_,
    );
}

my %LOADED;
sub _parse_event {
    my $self = shift;
    my $event = shift;

    return $LOADED{$event} if $LOADED{$event};

    my $pkg;
    if ($event =~ m/::/) {
        $pkg = $event;
    }
    else {
        $pkg = "Test::Stream::Event::$event";
    }

    my $file = $pkg;
    $file =~ s{::}{/};
    $file .= '.pm';
    unless ($INC{$file} || $pkg->can('new')) {
        my ($ok, $error) = try { require $file };
        chomp($error);
        confess "Could not load package '$pkg' for event '$event': $error"
            unless $ok;
    }

    $LOADED{$pkg}   = $event;
    $LOADED{$event} = $pkg;

    return $pkg;
}

# Shortcuts
# The indentation is for a better diff, will remove next commit
{
    sub ok {
        my $self = shift;
        my ($real_bool, $name, $diag) = @_;
        $self->send_event('Ok', real_bool => $real_bool, name => $name, diag => $diag);
    }

    sub note {
        my $self = shift;
        my ($message) = @_;
        $self->send_event('Note', message => $message);
    }

    sub diag {
        my $self = shift;
        my ($message) = @_;
        $self->send_event('Diag', message => $message);
    }

    sub plan {
        my $self = shift;
        my ($max, $directive, $reason) = @_;
        $self->send_event('Plan', max => $max, directive => $directive, reason => $reason);
    }

    sub bail {
        my $self = shift;
        my ($reason, $quiet) = @_;
        $self->send_event('Bail', reason => $reason, quiet => $quiet);
    }

    sub finish {
        my $self = shift;
        my ($tests_run, $tests_failed) = @_;
        $self->send_event('Finish', tests_run => $tests_run, tests_failed => $tests_failed);
    }

    sub subtest {
        my $self = shift;
        my ($real_bool, $name) = @_;
        $self->send_event('Subtest', real_bool => $real_bool, name => $name);
    }

    sub done_testing {
        return $_[0]->stream->done_testing(@_)
            unless $INC{'Test/Builder.pm'} && $Test::Builder::ORIG{done_testing} != \&Test::Builder::done_testing;

        local $Test::Builder::CTX = shift;
        my $out = Test::Builder->new->done_testing(@_);
        return $out;
    }
}

sub meta { is_tester($_[0]->{+FRAME}->[0]) }

sub inspect_todo {
    my ($pkg) = @_;
    my $meta = $pkg ? is_tester($pkg) : undef;

    no strict 'refs';
    return {
        TODO => [@TODO],
        $Test::Builder::Test ? (TB   => $Test::Builder::Test->{Todo})      : (),
        $meta                ? (META => $meta->{Test::Stream::Meta::TODO}) : (),
        $pkg                 ? (PKG  => ${"$pkg\::TODO"})                  : (),
    };
}

sub hide_todo {
    my $self = shift;

    my $pkg = $self->{+FRAME}->[0];
    my $meta = is_tester($pkg);

    my $found = inspect_todo($pkg);

    @TODO = ();
    $Test::Builder::Test->{Todo} = undef;
    $meta->{Test::Stream::Meta::TODO} = undef;
    {
        no strict 'refs';
        no warnings 'once';
        ${"$pkg\::TODO"} = undef;
    }

    return $found;
}

sub restore_todo {
    my $self = shift;
    my ($found) = @_;

    my $pkg = $self->{+FRAME}->[0];
    my $meta = is_tester($pkg);

    @TODO = @{$found->{TODO}};
    $Test::Builder::Test->{Todo} = $found->{TB};
    $meta->{Test::Stream::Meta::TODO} = $found->{META};
    {
        no strict 'refs';
        no warnings 'once';
        ${"$pkg\::TODO"} = $found->{PKG};
    }

    my $found2 = inspect_todo($pkg);

    for my $k (qw/TB META PKG/) {
        no warnings 'uninitialized';
        next if "$found->{$k}" eq "$found2->{$k}";
        die "INTERNAL ERROR: Mismatch! $k:\t$found->{$k}\n\t$found2->{$k}\n"
    }

    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Context - Object to represent a testing context.

=head1 DESCRIPTION

In testing it is important to have context. It is not helpful to simply say a
test failed, you want to know where it failed. This object is responsible for
tracking the context of each test that is run. It makes it possible to get the
file and line number where the failure occured .This object is also responsible
for generating almost all the events you will encounter.

=head1 SYNOPSYS

    use Test::Stream::Context qw/context/;

    sub my_tool {
        my $ctx = context();

        # Generate an event.
        $ctx->ok(1, "Pass!");
    }

    1;

=head1 EXPORTS

=over 4

=item $ctx = context()

This function is used to obtain a context. If there is already a context object
in scope this will return it, otherwise it will return a new one.

It is important that you never store a context object in a variable from a
higher scope, a package variable, or an object attribute. The scope of a
context matters a lot.

If you want to store a context for later reference use the C<snapshot()> method
to get a clone of it that is safe to store anywhere.

Note, C<context()> assumes you are at the lowest level of your tool, and looks
at the current caller. If you need it to look further you can call it with a
numeric argument which is added to the level. To clarify, calling C<context()>
is the same as calling C<context(0)>.

=back

=head1 METHODS

=over 4

=item $ctx->alert($MESSAGE)

This issues a warning at the calling context (filename and line number where
errors should be reported).

=item $ctx->throw($MESSAGE)

This throws an exception at the calling context (filename and line number where
errors should be reported).

=item ($package, $file, $line, $subname) = $ctx->call()

Get the caller details for the context. This is where errors should be
reported.

=item $pkg = $ctx->package

Get the context package.

=item $file = $ctx->file

Get the context filename.

=item $line = $ctx->line

Get the context line number.

=item $subname = $ctx->subname

Get the context subroutine name.

=item $ctx_copy = $ctx->snapshot

Get a copy of the context object that is safe to store for later reference.

=item $ctx->send($event)

Send an event to the correct L<Test::Stream> object.

=item $ctx = $class->peek

Get the current context object, if there is one.

=back

=head2 DANGEROUS ONES

=over 4

=item $ctx->set

=item $class->set($ctx)

Set the context object as the current one, replacing any that might already be
current.

=item $class->clear

Unset the current context.

=item $ctx->register_event($package)

=item $ctx->register_event($package, $name)

Register a new event type, creating the shortcut method to generate it. If
C<$name> is not provided it will be taken from the end of the package name, and
will be lowercased.

=item $hr = $ctx->events

Get the hashref that holds C<< (name => $package) >> pairs. This is the actual
ref used by the package, so please do not alter it.

=item $stash = $ctx->hide_todo

=item $ctx->restore_todo($stash)

These are used to temporarily hide the TODO value in ALL places where it might
be found. The returned C<$stash> must be used to restore it later.

=item $stash = $ctx->subtest_start($name, %params)

=item $stash = $ctx->subtest_stop($name)

Used to start and stop subtests in the test stream. The stash can be used to
configure and manipulate the subtest information. C<subtest_start> will hide
the current TODO settings, and unset the current context. C<subtest_stop> will
restore the TODO and reset the context back to what it was.

B<It is your job> to take the results in the stash and produce a
L<Test::Stream::Event::Subtest> event from them.

B<Using this directly is not recommended>.

=back

=head2 CLASS METHODS

B<Note:> These can effect all test packages, if that is not what you want do not use them!.

=over 4

=item $msg = Test::Stream::Context->push_todo($msg)

=item $msg = Test::Stream::Context->pop_todo()

=item $msg = Test::Stream::Context->peek_todo()

These manage a global todo stack. Any new context created will check here first
for a TODO. Changing this will not effect any existing context instances. This
is a reliable way to set a global todo that effects any/all packages.

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
