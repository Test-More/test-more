package Test::Stream;
use strict;
use warnings;

our $VERSION = '1.301001_107';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use Test::Stream::Carp qw/croak confess carp/;
use Test::Stream::Util qw/try/;
use Test::Stream::Threads;

############################
# {{{ Hub stack management #
############################

use Test::Stream::Hub;
use Test::Stream::Event::Finish;
use Test::Stream::ExitMagic;
use Test::Stream::ExitMagic::Context;

# Do not repeat Test::Builders singleton error, these are lexical vars, not package vars.
my ($root, @stack, $magic);

END {
    $root->fork_cull if $root && $root->_use_fork && $$ == $root->pid;
    $magic->do_magic($root) if $magic && $root && !$root->no_ending
}

sub _stack { @stack }

*current_hub = \&shared;
sub shared {
    return $stack[-1] if @stack;

    @stack = ($root = Test::Stream::Hub->new());
    $root->set_no_ending(0);

    $magic = Test::Stream::ExitMagic->new;

    return $root;
}

sub clear {
    $root->no_ending(1);
    $root  = undef;
    $magic = undef;
    @stack = ();
}

sub intercept_start {
    my $class = shift;
    my ($new) = @_;

    my $old = $stack[-1];

    unless($new) {
        $new = Test::Stream::Hub->new();

        $new->set_exit_on_disruption(0);
        $new->set_use_tap(0);
        $new->set_use_legacy(0);
    }

    push @stack => $new;

    return ($new, $old);
}

sub intercept_stop {
    my $class = shift;
    my ($current) = @_;
    croak "Stream stack inconsistency" unless $current == $stack[-1];
    pop @stack;
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

############################
# Hub stack management }}} #
############################

####################################
# {{{ Exported Tools and shortcuts #
####################################

use Test::Stream::Context qw/context inspect_todo/;
use Test::Stream::IOSets  qw/OUT_STD OUT_ERR OUT_TODO/;
use Test::Stream::Meta    qw/MODERN ENCODING init_tester is_tester/;
use Test::Stream::State   qw/PLAN COUNT FAILED ENDED LEGACY/;

BEGIN {
    *peek_context  = \&Test::Stream::Context::peek;
    *clear_context = \&Test::Stream::Context::clear;
    *set_context   = \&Test::Stream::Context::set;
    *push_todo     = \&Test::Stream::Context::push_todo;
    *pop_todo      = \&Test::Stream::Context::pop_todo;
    *peek_todo     = \&Test::Stream::Context::peek_todo;
}

use Test::Stream::Exporter;
default_exports qw/context/;
exports qw{
    listen munge follow_up
    enable_forking cull
    peek_todo push_todo pop_todo set_todo inspect_todo
    is_tester init_tester
    is_modern set_modern
    peek_context clear_context set_context
    state_count state_failed state_plan state_ended is_passing
    current_hub

    disable_tap enable_tap subtest_buffering subtest_spec tap_encoding
    enable_numbers disable_numbers set_tap_outputs get_tap_outputs
};
Test::Stream::Exporter->cleanup();

sub before_import {
    my $class = shift;
    my ($importer, $list) = @_;

    my $meta = init_tester($importer);
    $meta->{+MODERN} = 1;

    my $other  = [];
    my $idx    = 0;
    my $hub = shared();

    while ($idx <= $#{$list}) {
        my $item = $list->[$idx++];
        next unless $item;

        if ($item eq 'use_subtest_buffering') {
            $hub->subtest_buffering($list->[$idx++]);
        }
        elsif ($item eq 'use_subtest_spec') {
            $hub->subtest_spec($list->[$idx++]);
        }
        elsif ($item eq 'utf8') {
            $hub->io_sets->init_encoding('utf8');
            $meta->{+ENCODING} = 'utf8';
        }
        elsif ($item eq 'encoding') {
            my $encoding = $list->[$idx++];

            croak "encoding '$encoding' is not valid, or not available"
                unless Encode::find_encoding($encoding);

            $hub->io_sets->init_encoding($encoding);
            $meta->{+ENCODING} = $encoding;
        }
        elsif ($item eq 'concurrency') {
            my $model = $list->[$idx++];
            $hub->use_fork(ref $model ? @$model : $model);
        }
        elsif ($item eq 'enable_fork') {
            $hub->use_fork;
        }
        else {
            push @$other => $item;
        }
    }

    @$list = @$other;

    return;
}

sub cull            { shared()->fork_cull()        }
sub listen(&)       { shared()->listen($_[0])      }
sub munge(&)        { shared()->munge($_[0])       }
sub follow_up(&)    { shared()->follow_up($_[0])   }
sub enable_forking  { shared()->use_fork(@_)       }
sub disable_tap     { shared()->set_use_tap(0)     }
sub enable_tap      { shared()->set_use_tap(1)     }
sub enable_numbers  { shared()->set_use_numbers(1) }
sub disable_numbers { shared()->set_use_numbers(0) }
sub state_count     { shared()->count()            }
sub state_failed    { shared()->failed()           }
sub state_plan      { shared()->plan()             }
sub state_ended     { shared()->ended()            }
sub is_passing      { shared()->is_passing         }

sub tap_encoding {
    my ($encoding) = @_;

    require Encode;

    croak "encoding '$encoding' is not valid, or not available"
        unless $encoding eq 'legacy' || Encode::find_encoding($encoding);

    my $ctx = context();
    $ctx->hub->io_sets->init_encoding($encoding);

    my $meta = init_tester($ctx->package);
    $meta->{+ENCODING} = $encoding;
}

sub subtest_buffering {
    my $hub = shared();
    $hub->subtest_buffering(@_) if @_;
    $hub->subtest_buffering();
}

sub subtest_spec {
    my $hub = shared();
    $hub->subtest_spec(@_) if @_;
    $hub->subtest_spec();
}

sub is_modern {
    my ($package) = @_;
    my $meta = is_tester($package) || croak "'$package' is not a tester package";
    return $meta->modern ? 1 : 0;
}

sub set_modern {
    my $package = shift;
    croak "set_modern takes a package and a value" unless @_;
    my $value = shift;
    my $meta = is_tester($package) || croak "'$package' is not a tester package";
    return $meta->set_modern($value);
}

sub set_todo {
    my ($pkg, $why) = @_;
    my $meta = is_tester($pkg) || croak "'$pkg' is not a tester package";
    $meta->set_todo($why);
}

sub set_tap_outputs {
    my %params = @_;
    my $encoding = delete $params{encoding} || 'legacy';
    my $std      = delete $params{std};
    my $err      = delete $params{err};
    my $todo     = delete $params{todo};

    my @bad = keys %params;
    croak "set_tap_output does not recognise these keys: " . join ", ", @bad
        if @bad;

    my $ioset = shared()->io_sets;
    my $enc = $ioset->init_encoding($encoding);

    $enc->[OUT_STD]  = $std  if $std;
    $enc->[OUT_ERR]  = $err  if $err;
    $enc->[OUT_TODO] = $todo if $todo;

    return $enc;
}

sub get_tap_outputs {
    my ($enc) = @_;
    my $set = shared()->io_sets->init_encoding($enc || 'legacy');
    return {
        encoding => $enc || 'legacy',
        std      => $set->[0],
        err      => $set->[1],
        todo     => $set->[2],
    };
}

####################################
# Exported Tools and shortcuts }}} #
####################################

# This is here to satisfy the Test::SharedFork patch until it is repatched
sub use_fork { croak "do not use this" }

sub CLONE {
    for my $hub (Test::Stream->_stack()) {
        next unless defined $hub->pid;
        next unless defined $hub->tid;

        next if $$ == $hub->pid && get_tid() == $hub->tid;

        $hub->set_in_subthread(1);
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream - A modern infrastructure for writing test tools.

=head1 SYNOPSIS

    use Test::Stream qw/context/;

    use Test::Stream::Exporter;
    default_exports qw/my_ok/; # Export 'my_ok' by default
    exports qw/my_is/;         # Export 'my_is' by request

    sub my_ok {
        my ($bool, $name) = @_;
        my $ctx = context(); // Get the current context
        $ctx->ok($bool, $name);
        return $bool;
    }

    sub my_is {
        my ($got, $want, $name) = @_;
        my $ctx = context();
        my $bool = $got eq $want;  # This does not account for undef, numerics, or refs
        $ctx->ok($bool, $name);
        return $bool;
    }

    1;

=head1 DESCRIPTION

Test::Stream is a testing framework designed to replace Test::Builder. To be
precise the project forked L<Test::Builder> and refactored it into its current
design. The framework focuses on backwords compatability with L<Test::Builder>,
and ease of use for testing tool authors.

Most tools written with L<Test::Builder> will work fine and play nicely with
Test::Stream based tools. Test::More gives you everything L<Test::Builder>
does, and a whole lot more. If you are looking to write a new testing tool, or
update an old one, this is the framework for you!

=head1 IMPORT ARGUMENTS

Any import argument not recognised will be treated as an export, if it is not a
valid export an exception will be thrown.

=over 4

=item use_subtest_buffering => $BOOL

Enable or disable buffering of subtest results. Buffering the results causes
the subtest 'ok' to be displayed before the results inside the subtest. This is
primarily useful when using threads or fork.

=item use_subtest_spec => 'legacy'

=item use_subtest_spec => 'block'

This is used to set the specification used to render subtests. Currenly there
is no TAP standard way to render subtests, all current methods are hacks that
take advantage of various TAP parsing loopholes.

The 'legacy' spec is the default, it uses indentation for subtest results:

    ok 1 - a result
    # Starting subtest X
        ok 1 - subtest X result 1
        ok 2 - subtest X result 2
        1..2
    ok 2 - subtest X final result

The 'block' spec forces buffering, it wraps results in a block:

    ok 1 - a result
    ok 2 - subtest X final result {
        ok 1 - subtest X result 1
        ok 2 - subtest X result 2
        1..2
    # }

=item concurrency => []

=item concurrency => 'Test::Stream::Concurrency::MODEL'

=item concurrency => ['Test::Stream::Concurrency::MODEL1', 'FALLBACK', ...]

Enable concurrency, and specify the model. If no model is provided (empty
array) L<Test::Stream::Concurrency::Files> is assumed. All specified models are
tried in order until one is found that works on the current platform. If none
work the fallback of L<Test::Stream::Concurrency::Files> is used.

=item 'enable_fork'

Currently this is the same as
C<< use Test::Stream concurrency => 'Test::Stream::Concurrency::Files' >>.
However we reserve the right to alter the default concurrency models at any
time, if it matters to you then you should specify one using the C<concurrency>
argument.

Turns on support for code that forks. This is not activated by default because
it adds ~30ms to the Test::More compile-time, which can really add up in large
test suites. Turn it on only when needed.

=item 'utf8'

Set the TAP encoding to utf8

=item encoding => '...'

Set the TAP encoding.

=back

=head1 COMMON TASKS

=head2 MODIFYING EVENTS

    use Test::Stream qw/ munge /;

    munge {
        my ($hub, $event, @subevents) = @_;

        if($event->isa('Test::Stream::Diag')) {
            $event->set_message( "KILROY WAS HERE: " . $event->message );
        }
    };

=head2 REPLACING TAP WITH ALTERNATIVE OUTPUT

    use Test::Stream qw/ disable_tap listen /;

    disable_tap();

    listen {
        my $hub = shift;
        my ($event, @subevents) = @_;

        # Tracking results in a db?
        my $id = log_event_to_db($e);
        log_subevent_to_db($id, $_) for @subevents;
    }

=head2 END OF TEST BEHAVIORS

    use Test::Stream qw/ follow_up is_passing /;

    follow_up {
        my ($context) = @_;

        if (is_passing()) {
            print "KILROY Says the test file passed!\n";
        }
        else {
            print "KILROY is not happy with you!\n";
        }
    };

=head2 ENABLING FORKING SUPPORT

    use Test::Stream 'enable_fork';
    use Test::More;

    # This all just works!
    my $pid = fork();
    if ($pid) { # Parent
        ok(1, "From Parent");
    }
    else { # child
        ok(1, "From Child");
        exit 0;
    }

    done_testing;

or:

    use Test::Stream qw/ enable_forking /;
    use Test::More;

    enable_forking();

    # This all just works now!
    my $pid = fork();
    if ($pid) { # Parent
        ok(1, "From Parent");
    }
    else { # child
        ok(1, "From Child");
        exit 0;
    }

    done_testing;

B<Note:> Result order between processes is not guarenteed, but the test number
is handled for you meaning you don't need to care.

Results:

    ok 1 - From Child
    ok 2 - From Parent

Or:

    ok 1 - From Parent
    ok 2 - From Child

=head2 REDIRECTING TAP OUTPUT

You may omit any arguments to leave a specific handle unchanged. It is not
possible to set a handle to undef or 0 or any other false value.

    use Test::Stream qw/ set_tap_outputs /;

    set_tap_outputs(
        encoding => 'legacy',           # Default,
        std      => $STD_IO_HANDLE,     # equivilent to $TB->output()
        err      => $ERR_IO_HANDLE,     # equivilent to $TB->failure_output()
        todo     => $TODO_IO_HANDLE,    # equivilent to $TB->todo_output()
    );

B<Note:> Each encoding has independant filehandles.

=head1 GENERATING EVENTS

=head2 EASY WAY

The best way to generate an event is through a L<Test::Stream::Context>
object. All events have a method associated with them on the context object.
The method will be the last part of the evene package name lowercased, for
example L<Test::Stream::Event::Ok> can be issued via C<< $context->ok(...) >>.

    use Test::Stream qw/ context /;
    my $context = context();
    $context->send_event('EVENT_TYPE', ...);

The 5 primary event types each have a shortcut method on
L<Test::Stream::Context>:

=over 4

=item $context->ok($bool, $name, \@diag)

Issue an L<Test::Stream::Event::Ok> event.

=item $context->diag($msg)

Issue an L<Test::Stream::Event::Diag> event.

=item $context->note($msg)

Issue an L<Test::Stream::Event::Note> event.

=item $context->plan($max, $directive, $reason)

Issue an L<Test::Stream::Event::Plan> event. C<$max> is the number of expected
tests. C<$directive> is a plan directive such as 'no_plan' or 'skip_all'.
C<$reason> is the reason for the directive (only applicable to skip_all).

=item $context->bail($reason)

Issue an L<Test::Stream::Event::Bail> event.

=back

=head2 HARD WAY

This is not recommended, but it demonstrates just how much the context shortcut
methods do for you.

    # First make a context
    my $context = Test::Stream::Context->new(
        frame     => ..., # Where to report errors
        hub       => ..., # Test::Stream object to use
        encoding  => ..., # encoding from test package meta-data
        in_todo   => ..., # Are we in a todo?
        todo      => ..., # Which todo message should be used?
        modern    => ..., # Is the test package modern?
        pid       => ..., # Current PID
        skip      => ..., # Are we inside a 'skip' state?
        provider  => ..., # What tool created the context?
    );

    # Make the event
    my $ok = Test::Stream::Event::Ok->new(
        # Should reflect where the event was produced, NOT WHERE ERRORS ARE REPORTED
        created => [__PACKAGE__, __FILE__,              __LINE__],
        context => $context,     # A context is required
        in_subtest => 0,

        pass => $bool,
        name => $name,
        diag => \@diag,
    );

    # Send the event to the hub.
    Test::Stream->shared->send($ok);

=head2 DEFAULT EXPORTS

All of these are functions. These functions all effect the current-shared
L<Test::Stream> object only.

=over 4

=item $context = context()

=item $context = context($add_level)

This will get the correct L<Test::Stream::Context> object. This may be one that
was previously initialized, or it may generate a new one. Read the
L<Test::Stream::Context> documentation for more info.

Note, C<context()> assumes you are at the lowest level of your tool, and looks
at the current caller. If you need it to look further you can call it with a
numeric argument which is added to the level. To clarify, calling C<context()>
is the same as calling C<context(0)>.

=back

=head1 AVAILABLE EXPORTS

All of these are functions. These functions all effect the current-shared
L<Test::Stream> object only.

=head2 EVENT MANAGEMENT

These let you install a callback that is triggered for all primary events. The
first argument is the L<Test::Stream> object, the second is the primary
L<Test::Stream::Event>, any additional arguments are subevents. All subevents
are L<Test::Stream::Event> objects which are directly tied to the primary one.
The main example of a subevent is the failure L<Test::Stream::Event::Diag>
object associated with a failed L<Test::Stream::Event::Ok>, events within a
subtest are another example.

=over 4

=item listen { my ($hub, $event, @subevents) = @_; ... }

Listen callbacks happen just after TAP is rendered (or just after it would be
rendered if TAP is disabled).

=item munge { my ($hub, $event, @subevents) = @_; ... }

Muinspect_todonge callbacks happen just before TAP is rendered (or just before
it would be rendered if TAP is disabled).

=back

=head2 POST-TEST BEHAVIOR

=over 4

=item follow_up { my ($context) = @_; ... }

A followup callback allows you to install behavior that happens either when
C<done_testing()> is called, or when the test file completes.

B<CAVEAT:> If done_testing is not used, the callback will happen in the
C<END {...}> block used by L<Test::Stream> to enact magic at the end of the
test.

=back

=head2 CONCURRENCY

=over 4

=item enable_forking()

Turns forking support on. This turns on a synchronization method that *just
works* when you fork inside a test. This must be turned on prior to any
forking.

=item cull()

This can only be called in the main process or thread. This is a way to
manually pull in results from other processes or threads. Typically this
happens automatically, but this allows you to ensure results have been gathered
by a specific point.

=back

=head2 CONTROL OVER TAP

=over 4

=item enable_tap()

Turn TAP on (on by default).

=item disable_tap()

Turn TAP off.

=item enable_numbers()

Show test numbers when rendering TAP.

=item disable_numbers()

Do not show test numbers when rendering TAP.

=item subtest_buffering($BOOL)

Turn subtest buffering on/off.

=item subtest_spec($NAME)

Set the subtest specification to use.

Available options: C<'legacy'>, C<'block'>

The 'legacy' spec is the default, it uses indentation for subtest results:

    ok 1 - a result
    # Starting subtest X
        ok 1 - subtest X result 1
        ok 2 - subtest X result 2
        1..2
    ok 2 - subtest X final result

The 'block' spec forces buffering, it wraps results in a block:

    ok 1 - a result
    ok 2 - subtest X final result {
        ok 1 - subtest X result 1
        ok 2 - subtest X result 2
        1..2
    # }

=item tap_encoding($ENCODING)

This lets you change the encoding for TAP output. This only effects the current
test package.

=item set_tap_outputs(encoding => 'legacy', std => $IO, err => $IO, todo => $IO)

This lets you replace the filehandles used to output TAP for any specific
encoding. All fields are optional, any handles not specified will not be
changed. The C<encoding> parameter defaults to 'legacy'.

B<Note:> The todo handle is used for failure output inside subtests where the
subtest was started already in todo.

=item $hashref = get_tap_outputs($encoding)

'legacy' is used when encoding is not specified.

Returns a hashref with the output handles:

    {
        encoding => $encoding,
        std      => $STD_HANDLE,
        err      => $ERR_HANDLE,
        todo     => $TODO_HANDLE,
    }

B<Note:> The todo handle is used for failure output inside subtests where the
subtest was started already in todo.

=back

=head2 TEST PACKAGE METADATA

=over 4

=item $bool = is_modern($package)

Check if a test package has the 'modern' flag.

B<Note:> Throws an exception if C<$package> is not already a test package.

=item set_modern($package, $value)

Turn on the modern flag for the specified test package.

B<Note:> Throws an exception if C<$package> is not already a test package.

=back

=head2 TODO MANAGEMENT

=over 4

=item push_todo($todo)

=item $todo = pop_todo()

=item $todo = peek_todo()

These can be used to manipulate a global C<todo> state. When a true value is at
the top of the todo stack it will effect any events generated via an
L<Test::Stream::Context> object. Typically all events are generated this way.

=item set_todo($package, $todo)

This lets you set the todo state for the specified test package. This will
throw an exception if the package is not a test package.

=item $todo_hashref = inspect_todo($package)

=item $todo_hashref = inspect_todo()

This lets you inspect the TODO state. Optionally you can specify a package to
inspect. The return is a hashref with several keys:

    {
        TODO => $TODO_STACK_ARRAYREF,
        TB   => $TEST_BUILDER_TODO_STATE,
        META => $PACKAGE_METADATA_TODO_STATE,
        PKG  => $package::TODO,
    }

This lets you see what todo states are set where. This is primarily useful when
debugging to see why something is unexpectedly TODO, or when something is not
TODO despite expectations.

=back

=head2 TEST PACKAGE MANAGEMENT

=over 4

=item $meta = is_tester($package)

Check if a package is a tester, if it is the meta-object for the tester is
returned.

=item $meta = init_tester($package)

Set the package as a tester and return the meta-object. If the package is
already a tester it will return the existing meta-object.

=back

=head2 CONTEXTUAL INFORMATION

=over 4

=item $hub = current_hub()

This will return the current L<Test::Stream> Object. L<Test::Stream> objects
typically live on a global stack, the topmost item on the stack is the one that
is normally used.

=back

=head2 TEST STATE

=over 4

=item $num = state_count()

Check how many tests have been run.

=item $num = state_failed()

Check how many tests have failed.

=item $plan_event = state_plan()

Check if a plan has been issued, if so the L<Test::Stream::Event::Plan>
instance will be returned.

=item $bool = state_ended()

True if the test is complete (after done_testing).

=item $bool = is_passing()

Check if the test state is passing.

=back

=head1 HUB STACK FUNCTIONS

At any point there can be any number of hubs. Most hubs will be present
in the hub stack. The stack is managed via a collection of class methods.
You can always access the "current" or "central" hub using
C<< Test::Stream->shared >>. If you want your events to go where they are
supposed to then you should always send them to the shared hub.

It is important to note that any toogle, control, listener, munger, etc.
applied to a hub will effect only that hub. Independant hubs, hubs down the
stack, and hubs added later will not get any settings from other hubs. Keep
this in mind if you take it upon yourself to modify the hub stack.

=over 4

=item $hub = Test::Stream::shared

=item $hub = Test::Stream->shared

Get the current shared hub. The shared hub is the hub at the top of
the stack.

=item Test::Stream::clear

=item Test::Stream->clear

Completely remove the hub stack. It is very unlikely you will ever want to
do this.

=item ($new, $old) = Test::Stream->intercept_start($new)

=item ($new, $old) = Test::Stream->intercept_start

Push a new hub to the top of the stack. If you do not provide a stack a new
one will be created for you. If you have one created for you it will have the
following differences from a default stack:

    $new->set_exit_on_disruption(0);
    $new->set_use_tap(0);
    $new->set_use_legacy(0);

=item Test::Stream->intercept_stop($top)

Pop the stack, you must pass in the instance you expect to be popped, there
will be an exception if they do not match.

=item Test::Stream->intercept(sub { ... })

    Test::Stream->intercept(sub {
        my ($new, $old) = @_;

        ...
    });

Temporarily push a new hub to the top of the stack. The codeblock you pass
in will be run. Once your codeblock returns the stack will be popped and
restored to the previous state.

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

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

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
