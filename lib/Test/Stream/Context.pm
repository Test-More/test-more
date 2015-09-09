package Test::Stream::Context;
use strict;
use warnings;

use Scalar::Util qw/weaken/;
use Carp qw/confess croak longmess/;
use Test::Stream::Util qw/get_tid try pkg_to_file/;

use Test::Stream::Sync;
use Test::Stream::DebugInfo;

# Preload some key event types
my %LOADED = (
    map {
        require "Test/Stream/Event/$_.pm";
        my $pkg = "Test::Stream::Event::$_";
        ( $pkg => $pkg, $_ => $pkg )
    } qw/Ok Diag Note Plan Bail Exception Waiting/
);

# Stack is ok to cache.
our $STACK = Test::Stream::Sync->stack;
our @ON_INIT;
our @ON_RELEASE;
our %CONTEXTS;

sub ON_INIT    { shift; push @ON_INIT => @_ }
sub ON_RELEASE { shift; push @ON_RELEASE => @_ }

END { _do_end() }

sub _do_end {
    my $real = $?;
    my $new  = $real;

    my @unreleased = grep { $_ && $_->debug->pid == $$ } values %CONTEXTS;
    if (@unreleased) {
        $new = 255;

        $_->debug->alert("context object was never released! This means a testing tool is behaving very badly")
            for @unreleased;
    }

    $? = $new;
}

use Test::Stream::Exporter qw/import exports export/;
exports qw/context/;
export release => sub($;@) {
    $_[0]->release;
    shift; # Remove undef that used to be our $self reference.
    return @_ > 1 ? @_ : $_[0];
};
no Test::Stream::Exporter;

use Test::Stream::HashBase(
    accessors => [qw/stack hub debug _on_release _depth _err _no_destroy_warning/],
);

sub init {
    confess "The 'debug' attribute is required"
        unless $_[0]->{+DEBUG};

    confess "The 'hub' attribute is required"
        unless $_[0]->{+HUB};

    $_[0]->{+_DEPTH} = 0 unless defined $_[0]->{+_DEPTH};

    $_[0]->{+_ERR} = $@;
}

sub snapshot { bless {%{$_[0]}}, __PACKAGE__ }

sub release {
    my ($self) = @_;
    return $_[0] = undef if Internals::SvREFCNT(%$self) != 2;

    my $hub = $self->{+HUB};
    my $hid = $hub->{hid};

    if (!$CONTEXTS{$hid} || $self != $CONTEXTS{$hid}) {
        $_[0] = undef;
        croak "release() should not be called on a non-canonical context.";
    }

    # Remove the weak reference, this will also prevent the destructor from
    # having an issue.
    # Remove the key itself to avoid a slow memory leak
    delete $CONTEXTS{$hid};

    if (my $cbk = $self->{+_ON_RELEASE}) {
        $_->($self) for reverse @$cbk;
    }
    if (my $hcbk = $hub->{_context_release}) {
        $_->($self) for reverse @$hcbk;
    }
    $_->($self) for reverse @ON_RELEASE;

    return;
}

sub DESTROY {
    my ($self) = @_;

    return unless $self->{+HUB};
    my $hid = $self->{+HUB}->hid;

    return unless $CONTEXTS{$hid} && $CONTEXTS{$hid} == $self;
    return unless "$@" eq "" . $self->{+_ERR};

    my $debug = $self->{+DEBUG} || return;
    my $frame = $debug->frame;

    my $mess = longmess;

    warn <<"    EOT" unless $self->{+_NO_DESTROY_WARNING} || $self->{+DEBUG}->pid != $$ || $self->{+DEBUG}->tid != get_tid;
Context was not released! Releasing at destruction.
Context creation details:
  Package: $frame->[0]
     File: $frame->[1]
     Line: $frame->[2]
     Tool: $frame->[3]

Trace: $mess
    EOT

    # Remove the key itself to avoid a slow memory leak
    delete $CONTEXTS{$hid};
    if(my $cbk = $self->{+_ON_RELEASE}) {
        $_->($self) for reverse @$cbk;
    }
    if (my $hcbk = $self->{+HUB}->{_context_release}) {
        $_->($self) for reverse @$hcbk;
    }
    $_->($self) for reverse @ON_RELEASE;
    return;
}

sub do_in_context {
    my $self = shift;
    my ($sub, @args) = @_;

    my $hub = $self->{+HUB};
    my $hid = $hub->hid;

    my $old = $CONTEXTS{$hid};

    weaken($CONTEXTS{$hid} = $self);
    my ($ok, $err) = &try($sub, @args);
    if ($old) {
        weaken($CONTEXTS{$hid} = $old);
        $old = undef;
    }
    else {
        delete $CONTEXTS{$hid};
    }
    die $err unless $ok;
}

sub context {
    my %params = (level => 0, wrapped => 0, @_);

    croak "context() called, but return value is ignored"
        unless defined wantarray;

    my $stack = $params{stack} || $STACK;
    my $hub = $params{hub} || @$stack ? $stack->[-1] : $stack->top;
    my $hid = $hub->{hid};
    my $current = $CONTEXTS{$hid};

    my $level = 1 + $params{level};
    my ($pkg, $file, $line, $sub) = caller($level);
    unless ($pkg) {
        confess "Could not find context at depth $level" unless $params{fudge};
        ($pkg, $file, $line, $sub) = caller(--$level) while ($level >= 0 && !$pkg);
    }

    my $depth = $level;
    $depth++ while caller($depth + 1) && (!$current || $depth <= $current->{+_DEPTH} + $params{wrapped});
    $depth -= $params{wrapped};

    if ($current && $params{on_release} && $current->{+_DEPTH} < $depth) {
        $current->{+_ON_RELEASE} ||= [];
        push @{$current->{+_ON_RELEASE}} => $params{on_release};
    }

    return $current if $current && $current->{+_DEPTH} < $depth;

    # Handle error condition of bad level
    $current->_depth_error([$pkg, $file, $line, $sub, $depth])
        if $current;

    my $dbg = bless(
        {
            frame => [$pkg, $file, $line, $sub],
            pid   => $$,
            tid   => get_tid(),
            $hub->debug_todo,
        },
        'Test::Stream::DebugInfo'
    );

    $current = bless(
        {
            STACK()  => $stack,
            HUB()    => $hub,
            DEBUG()  => $dbg,
            _DEPTH() => $depth,
            _ERR()   => $@,
            $params{on_release} ? (_ON_RELEASE() => [$params{on_release}]) : (),
        },
        __PACKAGE__
    );

    weaken($CONTEXTS{$hid} = $current);

    $_->($current) for @ON_INIT;

    if (my $hcbk = $hub->{_context_init}) {
        $_->($current) for @$hcbk;
    }

    $params{on_init}->($current) if $params{on_init};

    return $current;
}

sub _depth_error {
    my $self = shift;
    my ($details) = @_;
    my ($pkg, $file, $line, $sub, $depth) = @$details;

    my $oldframe = $self->{+DEBUG}->frame;
    my $olddepth = $self->{+_DEPTH};

    my $mess = longmess();

    warn <<"    EOT";
context() was called to retrieve an existing context, however the existing
context was created in a stack frame at the same, or deeper level. This usually
means that a tool failed to release the context when it was finished.

Old context details:
   File: $oldframe->[1]
   Line: $oldframe->[2]
   Tool: $oldframe->[3]
  Depth: $olddepth

New context details:
   File: $file
   Line: $line
   Tool: $sub
  Depth: $depth

Trace: $mess

Removing the old context and creating a new one...
    EOT

    my $hid = $self->{+HUB}->hid;
    delete $CONTEXTS{$hid};
    $self->release;
}

sub throw {
    my ($self, $msg) = @_;
    $_[0]->release; # We have to act on $_[0] because it is aliased
    $self->debug->throw($msg);
}

sub alert {
    my ($self, $msg) = @_;
    $self->debug->alert($msg);
}

sub send_event {
    my $self  = shift;
    my $event = shift;
    my %args  = @_;

    my $pkg = $LOADED{$event} || $self->_parse_event($event);

    $self->{+HUB}->send(
        $pkg->new(
            debug => $self->{+DEBUG}->snapshot,
            %args,
        )
    );
}

sub build_event {
    my $self  = shift;
    my $event = shift;
    my %args  = @_;

    my $pkg = $LOADED{$event} || $self->_parse_event($event);

    $pkg->new(
        debug => $self->{+DEBUG}->snapshot,
        %args,
    );
}

sub ok {
    my $self = shift;
    my ($pass, $name, $diag) = @_;

    my $e = bless {
        debug => bless( {%{$self->{+DEBUG}}}, 'Test::Stream::DebugInfo'),
        pass  => $pass,
        name  => $name,
    }, 'Test::Stream::Event::Ok';
    $e->init;

    return $self->{+HUB}->send($e) if $pass;

    $diag ||= [];
    unshift @$diag => $e->default_diag;

    $e->set_diag($diag);

    $self->{+HUB}->send($e);
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
    my ($self, $max, $directive, $reason) = @_;
    if ($directive && $directive =~ m/skip/i) {
        $self->{+_NO_DESTROY_WARNING} = 1;
        $self = $self->snapshot;
        $_[0]->release;
    }

    $self->send_event('Plan', max => $max, directive => $directive, reason => $reason);
}

sub bail {
    my ($self, $reason) = @_;
    $self->{+_NO_DESTROY_WARNING} = 1;
    $self = $self->snapshot;
    $_[0]->release;
    $self->send_event('Bail', reason => $reason);
}

sub _parse_event {
    my $self = shift;
    my $event = shift;

    my $pkg;
    if ($event =~ m/^\+(.*)/) {
        $pkg = $1;
    }
    else {
        $pkg = "Test::Stream::Event::$event";
    }

    unless ($LOADED{$pkg}) {
        my $file = pkg_to_file($pkg);
        my ($ok, $err) = try { require $file };
        $self->throw("Could not load event module '$pkg': $err")
            unless $ok;

        $LOADED{$pkg} = $pkg;
    }

    confess "'$pkg' is not a subclass of 'Test::Stream::Event'"
        unless $pkg->isa('Test::Stream::Event');

    $LOADED{$event} = $pkg;

    return $pkg;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Context - Object to represent a testing context.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

The context object is the primary interface for authors of testing tools
written with L<Test::Stream>. The context object represents the context in
which a test takes place (File and Line Number), and provides a quick way to
generate events from that context. The context object also takes care of
sending events to the correct L<Test::Stream::Hub> instance.

=head1 SYNOPSIS

    use Test::Stream::Context qw/context release/;

    sub my_ok {
        my ($bool, $name) = @_;
        my $ctx = context();
        $ctx->ok($bool, $name);
        $ctx->release; # You MUST do this!
        return $bool;
    }

Context objects make it easy to wrap other tools that also use context. Once
you grab a context, any tool you call before releasing your context will
inherit it:

    sub wrapper {
        my ($bool, $name) = @_;
        my $ctx = context();
        $ctx->diag("wrapping my_ok");

        my $out = my_ok($bool, $name);
        $ctx->release; # You MUST do this!
        return $out;
    }

Notice above that we are grabbing a return value, then releasing our context,
then returning the value. We can combine these last 3 statements into a single
statement using the C<release> function:

    sub wrapper {
        my ($bool, $name) = @_;
        my $ctx = context();
        $ctx->diag("wrapping my_ok");

        # You must always release the context.
        release $ctx, my_ok($bool, $name);
    }

=head1 CRITICAL DETAILS

=over 4

=item You MUST always release the context when done with it

Releasing the context tells the system you are done with it. This gives it a
chance to run any necessary callbacks or cleanup tasks. If you forget to
release the context it will be released for you using a destructor, and it will
give you a warning.

In general the destructor is not preferred because it does not allow callbacks
to run some types of code, for example you cannot throw an exception from a
destructor.

=item You MUST NOT pass context objects around

When you obtain a context object it is made specifically for your tool and any
tools nested within. If you pass a context around you run the risk of polluting
other tools with incorrect context information.

If you are certain that you want a different tool to use the same context you
may pass it a snapshot. C<< $ctx->snapshot >> will give you a shallow clone of
the context that is safe to pass around or store.

=item You MUST NOT store or cache a context for later

As long as a context exists for a given hub, all tools that try to get a
context will get the existing instance. If you try to store the context you
will pollute other tools with incorrect context information.

If you are certain that you want to save the context for later, you can use a
snapshot. C<< $ctx->snapshot >> will give you a shallow clone of the context
that is safe to pass around or store.

C<context() has some mechanisms to protect you if you do cause a context to
persist beyond the scope in which it was obtained. In practice you should not
rely on these protections, and they are fairly noisy with warnings.

=item You SHOULD obtain your context as soon as possible in a given tool

You never know what tools you call from within your own tool will need a
context. Obtaining the context early ensures that nested tools can find the
context you want them to find.

=back

=head1 EXPORTS

All exports are optional, you must specify subs to import. If you want to
import all subs use '-all'.

    use Test::Stream::Context '-all';

=head2 context()

Usage:

=over 4

=item $ctx = context()

=item $ctx = context(%params)

=back

The C<context()> function will always return the current context to you. If
there is already a context active it will be returned. If there is not an
active context one will be generated. When a context is generated it will
default to using the file and line number where the currently running sub was
called from.

Please see the L</"CRITICAL DETAILS"> section for important rools about what
you can and acannot do with a context once it is obtained.

B<Note> This function will throw an exception if you ignore the context object
it returns.

=head3 OPTIONAL PARAMETERS

All parameters to C<context> are optional.

=over 4

=item level => $int

If you must obtain a context in a sub deper than your entry point you can use
this to tell it how many EXTRA stack frames to look back. If this option is not
provided the default of C<0> is used.

    sub third_party_tool {
        my $sub = shift;
        ... # Does not obtain a context
        $sub->();
        ...
    }

    third_party_tool(sub {
        my $ctx = context(level => 1);
        ...
        $ctx->release;
    });

=item wrapped => $int

Use this if you need to write your own tool that wraps a call to C<context()>
with the intent that it should return a context object.

    sub my_context {
        my %params = ( wrapped => 0, @_ );
        $params{wrapped}++;
        my $ctx = context(%params);
        ...
        return $ctx;
    }

    sub my_tool {
        my $ctx = my_context();
        ...
        $ctx->release;
    }

If you do not do this than tools you call that also check for a context will
notice that the context they grabbed was created at the same stack depth, which
will trigger protective measures that warn you and destroy the existing
context.

=item stack => $stack

Normally C<context()> looks at the global hub stack initialized in
L<Test::Stream::Sync>. If you are maintaining your own L<Test::Stream::Stack>
instance you may pass it in to be used instead of the global one.

=item hub => $hub

Use this parameter if you want to onbtain the context for a specific hub
instead of whatever one happens to be at the top of the stack.

=item on_init => sub { ... }

This lets you provide a callback sub that will be called B<ONLY> if your call
to c<context()> generated a new context. The callback B<WILL NOT> be called if
C<context()> is returning an existing context. The only argument passed into
the callback will be the context object itself.

    sub foo {
        my $ctx = context(on_init => sub { 'will run' });

        my $inner = sub {
            # This callback is not run since we are getting the existing
            # context from our parent sub.
            my $ctx = context(on_init => sub { 'will NOT run' });
            $ctx->release;
        }
        $inner->();

        $ctx->release;
    }

=item on_release => sub { ... }

This lets you provide a callback sub that will be called when the context
instance is released. This callback will be added to the returned context even
if an existing context is returned. If multiple calls to context add callbacks
then all will be called in reverse order when the context is finally released.

    sub foo {
        my $ctx = context(on_release => sub { 'will run second' });

        my $inner = sub {
            my $ctx = context(on_release => sub { 'will run first' });

            # Neither callback runs on this release
            $ctx->release;
        }
        $inner->();

        # Both callbacks run here.
        $ctx->release;
    }

=back

=head2 release()

Usage:

=over 4

=item release $ctx;

=item release $ctx, ...;

=back

This is intended as a shortcut that lets you release your context and return a
value in one statement. This function will get your context, and any other
arguments provided. It will release your context, then return everything else.
If you only provide one argument it will return that one argument as a scalar.
If you provide multiple arguments it will return them all as a list.

    sub scalar_tool {
        my $ctx = context();
        ...

        return release $ctx, 1;
    }

    sub list_tool {
        my $ctx = context();
        ...

        return release $ctx, qw/a b c/;
    }

This tool is most useful when you want to return the value you get from calling
a function that needs to see the current context:

    my $ctx = context();
    my $out = some_tool(...);
    $ctx->release;
    return $out;

We can combine the last 3 lines of the above like so:

    my $ctx = context();
    release $ctx, some_tool(...);

=head1 METHODS

=head2 CLASS METHODS

=over 4

=item Test::Stream::Context->ON_INIT(sub { ... }, ...)

=item Test::Stream::Context->ON_RELEASE(sub { ... }, ...)

These are B<GLOBAL> hooks into the context tools. Every sub added via ON_INIT
will be called every single time a new context is initialized. Every sub added
via ON_RELEASE will be called every single time a context is released.

Subs will recieve exactly 1 argument, that is the context itself. You should
not call C<release> on the context within your callback.

=back

=head2 INSTANCE METHODS

=over 4

=item $clone = $ctx->snapshot()

This will return a shallow clone of the context. The shallow clone is safe to
store for later.

=item $ctx->release()

This will release the context. It will also set the C<$ctx> variable to
C<undef> (it works regardless of what you name the variable).

=item $ctx->throw($message)

This will throw an exception reporting to the file and line number of the
context. This will also release the context for you.

=item $ctx->alert($message)

This will issue a warning from the file and line number of the context.

=item $stack = $ctx->stack()

This will return the L<Test::Stream::Stack> instance the context used to find
the current hub.

=item $hub = $ctx->hub()

This will return the L<Test::Stream::Hub> instance the context recognises as
the current one to which all events should be sent.

=item $dbg = $ctx->debug()

This will return the L<Test::Stream::DebugInfo> instance used by the context.

=item $ctx->do_in_context(\&code, @args);

Sometimes you have a context that is not current, and you want things to use it
as the current one. In these cases you can call
L<< $ctx->do_in_context(sub { ... }) >>. The codeblock will be run, and
anything inside of it that looks for a context will find the one on which the
method was called.

This B<DOES NOT> effect context on other hubs, only the hub used by the context
will be effected.

    my $ctx = ...;
    $ctx->do_in_context(sub {
        my $ctx = context(); # returns the $ctx the sub is called on
    });

=back

=head2 EVENT PRODUCTION METHODS

=over 4

=item $event = $ctx->ok($bool, $name)

=item $event = $ctx->ok($bool, $name, \@diag)

This will create an L<Test::Stream::Event::Ok> object for you. The diagnostics
array will be used on the object in the event of a failure, if the test passes
the diagnostics will be ignored.

=item $event = $ctx->note($message)

Send an L<Test::Stream::Event::Note>. This event prints a message to STDOUT.

=item $event = $ctx->diag($message)

Send an L<Test::Stream::Event::Diag>. This event prints a message to STDERR.

=item $event = $ctx->plan($max)

=item $event = $ctx->plan(0, 'SKIP', $reason)

This can be used to send an L<Test::Stream::Event::Plan> event. This event
usually takes either a number of tests you expect to run. Optionally you can
set the expected count to 0 and give the 'SKIP' directive with a reason to
cause all tests to be skipped.

=item $event = $ctx->bail($reason)

This sends an L<Test::Stream::Event::Bail> event. This event will completely
terminate all testing.

=item $event = $ctx->send_event($Type, %parameters)

This lets you build and send an event of any type. The C<$Type> argument should
be the event package name with C<Test::Stream::Event::> left off, or a fully
qualified package name prefixed with a '+'. The event is returned after it is
sent.

    my $event = $ctx->send_event('Ok', ...);

or

    my $event = $ctx->send_event('+Test::Stream::Event::Ok', ...);

=item $event = $ctx->build_event($Type, %parameters)

This is the same as C<send_event()>, except it builds and returns the event
without sending it.

=back

=head1 HOOKS

There are 2 types of hooks, init hooks, and release hooks. As the names
suggest, these hooks are triggered when contexts are created or released.

=head2 INIT HOOKS

These are called whenever a context is initialized. That means when a new
instance is created. These hooks are B<NOT> called every time something
requests a context, just when a new one is created.

=head3 GLOBAL

This is how you add a global init callback. Global callbacks happen for every
context for any hub or stack.

    Test::Stream::Context->ON_INIT(sub {
        my $ctx = shift;
        ...
    });

=head3 PER HUB

This is how you add an init callback for all contexts created for a given hub.
These callbacks will not run for other hubs.

    $hub->add_context_init(sub {
        my $ctx = shift;
        ...
    });

=head3 PER CONTEXT

This is how you specify an init hook that will only run if your call to
C<context()> generates a new context. The callback will be ignored if
C<context()> is returning an existing context.

    my $ctx = context(on_init => sub {
        my $ctx = shift;
        ...
    });

=head2 RELEASE HOOKS

These are called whenever a context is released. That means when the last
reference to the instance is about to be destroyed. These hooks are B<NOT>
called every time C<< $ctx->release >> is called.

=head3 GLOBAL

This is how you add a global release callback. Global callbacks happen for every
context for any hub or stack.

    Test::Stream::Context->ON_RELEASE(sub {
        my $ctx = shift;
        ...
    });

=head3 PER HUB

This is how you add a release callback for all contexts created for a given
hub. These callbacks will not run for other hubs.

    $hub->add_context_release(sub {
        my $ctx = shift;
        ...
    });

=head3 PER CONTEXT

This is how you add release callbacks directly to a context. The callback will
B<ALWAYS> be added to the context that gets returned, it does not matter if a
new one is generated, or if an existing one is returned.

    my $ctx = context(on_release => sub {
        my $ctx = shift;
        ...
    });

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
