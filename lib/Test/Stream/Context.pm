package Test::Stream::Context;
use strict;
use warnings;

use Scalar::Util qw/weaken/;

use Test::Stream::Carp qw/confess croak/;
use Test::Stream::Capabilities qw/CAN_FORK/;

use Test::Stream::Hub;
use Test::Stream::TAP;
use Test::Stream::Threads;
use Test::Stream::DebugInfo;

my @HUB_STACK;
my %CONTEXTS;
my $NO_WAIT;

use Test::Stream::Exporter qw/import export_to exports/;
exports qw/TOP_HUB PUSH_HUB POP_HUB NEW_HUB CULL context/;
no Test::Stream::Exporter;

# Set the exit status
my ($PID, $TID) = ($$, get_tid());
END {
    my $exit = $?;

    if ($PID != $$ || $TID != get_tid()) {
        $? = $exit;
        return;
    }

    if ($INC{'Test/Stream/IPC.pm'} && !$NO_WAIT) {
        my %seen;
        for my $hub (reverse @HUB_STACK) {
            my $ipc = $hub->ipc || next;
            next if $seen{$ipc}++;
            $ipc->waiting();
        }

        my $ipc_exit = IPC_WAIT();
        $exit ||= $ipc_exit;
    }

    my $dbg = Test::Stream::DebugInfo->new(
        frame => [ __PACKAGE__, __FILE__, __LINE__ + 4, 'END' ],
        detail => 'Test::Stream::Context END Block finalization',
    );
    my $hub_exit = 0;
    for my $hub (reverse @HUB_STACK) {
        next if $hub->no_ending;
        next if $hub->state->ended;
        $hub_exit += $hub->finalize($dbg, 1);
    }
    $exit ||= $hub_exit;

    if(my @unreleased = grep { $_ } values %CONTEXTS) {
        $exit ||= 255;
        for my $ctx (@unreleased) {
            $ctx->debug->alert("context object was never released! This means a testing tool is behaving very badly");
        }
    }

    $exit = 255 if $exit > 255;

    $? = $exit;
}

sub NO_WAIT { ($NO_WAIT) = @_ if @_; $NO_WAIT }

sub IPC_WAIT {
    my $fail = 0;

    while (CAN_FORK()) {
        my $pid = CORE::wait();
        my $err = $?;
        last if $pid == -1;
        next unless $err;
        $fail++;
        $err = $err >> 8;
        warn "Process $pid did not exit cleanly (status: $err)\n";
    }

    if (USE_THREADS) {
        for my $t (threads->list()) {
            $t->join;
            my $err = $t->error;
            my $tid = $t->tid();
            $fail++;
            chomp($err);
            warn "Thread $tid did not end cleanly\n";
        }
    }

    return 0 unless $fail;
    return 255;
}

sub NEW_HUB {
    shift @_ if $_[0] && $_[0] eq __PACKAGE__;

    my ($ipc, $formatter);
    if (@HUB_STACK) {
        $ipc = $HUB_STACK[-1]->ipc;
        $formatter = $HUB_STACK[-1]->format;
    }
    else {
        $formatter = Test::Stream::TAP->new;
        if ($INC{'Test/Stream/IPC.pm'}) {
            my ($driver) = Test::Stream::IPC->drivers;
            $ipc = $driver->new;
        }
    }

    my $hub = Test::Stream::Hub->new(
        formatter => $formatter,
        ipc       => $ipc,
        @_,
    );

    return $hub;
}

sub TOP_HUB {
    push @HUB_STACK => NEW_HUB() unless @HUB_STACK;
    $HUB_STACK[-1];
}

sub PEEK_HUB { @HUB_STACK ? $HUB_STACK[-1] : undef }

sub PUSH_HUB {
    my $hub = pop;
    push @HUB_STACK => $hub;
}

sub POP_HUB {
    my $hub = pop;
    confess "You cannot pop the root hub"
        if 1 == @HUB_STACK;
    confess "Hub stack mismatch, attempted to pop incorrect hub"
        unless $HUB_STACK[-1] == $hub;
    pop @HUB_STACK;
}

sub CULL { $_->cull for reverse @HUB_STACK }

use Test::Stream::HashBase(
    accessors => [qw/hub debug/],
);

sub init {
    confess "debug is required"
        unless $_[0]->{+DEBUG};

    confess "hub is required"
        unless $_[0]->{+HUB};
}

sub snapshot { bless {%{$_[0]}}, __PACKAGE__ }

sub context(;$) {
    croak "context() called, but return value is ignored"
        unless defined wantarray;

    my $hub = TOP_HUB();
    my $current = $CONTEXTS{$hub->hid};
    return $current if $current;

    # This is a good spot to poll for pending IPC results. This actually has
    # nothing to do with getting a context.
    $hub->cull;

    my $level = 1 + ($_[0] || 0);
    my ($pkg, $file, $line, $sub) = caller($level);
    confess "Could not find context at depth $level"
        unless $pkg;

    my $dbg = Test::Stream::DebugInfo->new(
        frame => [$pkg, $file, $line, $sub],
    );

    $current = bless(
        {
            HUB()   => $hub,
            DEBUG() => $dbg,
        },
        __PACKAGE__
    );

    weaken($CONTEXTS{$hub->hid} = $current);
    return $current;
}

sub set {
    my $self = shift;
    my $hub = TOP_HUB();
    weaken($CONTEXTS{$hub->hid} = $self);
}

sub unset {
    my $self = shift;
    my $hub = TOP_HUB();
    delete $CONTEXTS{$hub->hid} if $CONTEXTS{$hub->hid} == $self;
}

sub peek {
    my $hub = TOP_HUB();
    $CONTEXTS{$hub->hid}
}

sub clear {
    my $hub = TOP_HUB();
    delete $CONTEXTS{$hub->hid};
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

=head1 KEY CONCEPTS AND RESPONSIBILITIES

This class manages the singleton, and singleton-like object instances used by
all Test-Stream tools.

=head2 CONTEXT OBJECTS

Context objects are instances of L<Test::Stream::Context>. These are the
primary point of interaction into the Test-Stream framework.

A Context object is a semi-singleton in that they are not arbitrarily created
or creatable. At any given time there will be exactly 0 or 1 instances of a
context object per hub in the hub stack. If there is only 1 hub in the hub
stack, there will only be 1 context object, if any.

The 1 context object for any given hub will be destroyed automatically if there
are no external references to it. If there is an instance of the context object
for a given hub it will be returned any time you call C<context()>. If there
are no existing instances, a new one will be generated.

The context returned by C<context()> will always be the instance for whatever
hub is at the top of the stack.

=head2 THE HUB STACK

The L<Test::Stream::Hub> objects are responsbile for routing events and
maintaining state. In many cases you only ever need 1 hub object. However there
are times where it is useful to temporarily use a new hub. Some example use
cases of temporarily replacing the hub are subtests, and intercepting results
to test testing tools.

=head3 IPC

If you load L<Test::Stream::IPC> or an IPC driver BEFORE the root hub is
generated, then IPC will be used. IPC will not be loaded for you automatically.
When you request a new hub using C<NEW_HUB> it will inherit the IPC instance
from the current hub.

=head3 FORMATTER

The root hub will use L<Test::Stream::TAP> as its formatter by default. If you
want to change this you must get the hub either by using C<< $context->hub >>
or C<TOP_HUB()> and set/unset the formatter using the C<format()> method.

The formatter is inherited, that is if you use C<NEW_HUB> to create a new hub,
it will reference the current hubs formatter.

=head1 EXPORTS

B<Note:> Nothing is exported by default, you must choose what you want to
import.

Many of these also work fine as class methods on the Test::Stream::Context
class, when that is the case an example is provided.

=over 4

=item $ctx = context()

=item $ctx = context($level)

This is used to generate a context. Anything else that tries to get a context
will get this very same instance, until you remove all references to it.
As such it is important that you never save or return a context object.

This will demonstrate:

    my $ctx1 = context();
    my $ctx2 = context();    # Returns $ctx1 again
    ok($ctx1 == $ctx2, "Same Instance");
    my $addr = "$ctx1";      # Take the address of the object

    $ctx1 = undef;
    $ctx2 = indef;

    my $ctx3 = context();    # Returns a new instance, old one was destroyed.
    ok("$ctx3" ne $addr, "Got a completely new instance");

B<In other words never do this>:

    my $ctx = context();

    sub foo {
        $ctx->...;
    }

    sub bar {
        $ctx->...;
    }

Doing this would prevent anything else from ever getting the correct context,
everything will always get this context until the end of time.

If you I<REALLY> need to keep the context, use the C<snapshot()> method to
clone it safely.

The C<$level> argument is how far down the stack to look for the context frame.
If you do not specify the C<$level> then 0 is assumed. This means it will use
the call directly above the current scope. IF you are calling context at the
package level, instead of inside a sub, you need to set C<$level> to C<-1>.

=item $hub = TOP_HUB()

=item $hub = $class->TOP_HUB()

This will return the hub at the top of the stack. If there are no hubs on the
stack it will generate a root one for you.

=item $hub = NEW_HUB(%ARGS)

=item $hub = $class->NEW_HUB(%ARGS)

This will generate a new hub, any arguments are passed to the
L<Test::Stream::Hub> constructor. Unless you override them, this will set the
formatter and ipc instance to those of the current hub.

B<Note:> This does not add the hub to the hub stack.

=item PUSH_HUB($hub)

=item $class->PUSH_HUB($hub)

This is used to push a new hub onto the stack. This hub will be the hub used by
any new contexts until either a new hub is pushed above it, or it is popped.

=item POP_HUB($hub)

=item $class->POP_HUB($hub)

This is used to pop a hub off the stack. You B<Must> pass in the hub you think
you are popping. An exception will be thrown if you do not specify the hub to
expect, or the hub you expect is not on the top of the stack.

=item CULL()

=item $class->CULL()

This will cause all hubs in the current proc/thread to cull any IPC results
they have not yet collected.

=item NO_WAIT($bool)

=item $bool = NO_WAIT()

=item $class->NO_WAIT($bool)

=item $bool = $class->NO_WAIT()

Normally Test::Stream::Context will wait on all child processes and join all
non-detached threads before letting the parent process end. Setting this to
true will prevent this behavior.

=back

=head1 METHODS

=over 4

=item $hub = $ctx->hub()

This retrieves the L<Test::Stream::Hub> object associated with the current
context.

=item $dbg = $ctx->debug()

This retrieves the L<Test::Stream::DebugInfo> object associated with the
current context.

=item $copy = $ctx->snapshot;

This will make a B<SHALLOW> copy of the context object. This copy will have the
same hub, and the same instance of L<Test::Stream::DebugInfo>. However this
shallow copy can be saved without locking the context forever.

=item $ctx->set

This can be used to set the context object to be the one true context for the
current hub.

=item $ctx->unset

This can be used to forcfully drop a context object so that it is no longer the
one true context for the current hub.

=item $ctx = $class->peek

This can be used to see if there is already a context for the current hub. This
will return undef if there is no current hub.

=item $class->clear

Remove the one true context for the current hub.

=back

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
