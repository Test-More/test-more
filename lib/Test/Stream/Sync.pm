package Test::Stream::Sync;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/reftype blessed/;

use Test::Stream::Capabilities qw/CAN_FORK/;
use Test::Stream::Util qw/get_tid USE_THREADS pkg_to_file/;

use Test::Stream::DebugInfo;
use Test::Stream::Stack;

# This package is NOT an object. It is global in nature and I don't want people
# fscking with it. It is small, with only the following variables. These are
# lexicals on purpose to prevent anyone from touching them directly.
# I know this may seem awful, but thats why this package is so small, this is
# the only place I need to lock down. This is to prevent people from doing some
# of the awful things they did with Test::Builder.
my $PID       = $$;
my $TID       = get_tid();
my $NO_WAIT   = 0;
my $INIT      = undef;
my $IPC       = undef;
my $STACK     = undef;
my $FORMAT    = undef;
my @HOOKS     = ();
my $LOADED    = 0;
my @POST_LOAD = ();

# The only valid reason to touch these internals is to test them. As such the
# internals can be exposed if the package is loaded from itself, and even then
# it warns in-case someone tries to do it for the wrong reasons.
# This must ONLY be used in the unit tests for this package.
{
    my $caller = caller || '';
    if ($caller eq __PACKAGE__) {
        warn "Enabling Test::Stream::Sync debug features, this is normally not desired!";

        *GUTS = sub {
            return {
                PID       => \$PID,
                TID       => \$TID,
                NO_WAIT   => \$NO_WAIT,
                INIT      => \$INIT,
                IPC       => \$IPC,
                STACK     => \$STACK,
                FORMAT    => \$FORMAT,
                HOOKS     => \@HOOKS,
                LOADED    => \$LOADED,
                POST_LOAD => \@POST_LOAD,
            };
        };

        *GUTS_SNAPSHOT = sub {
            return {
                PID       => $PID,
                TID       => $TID,
                NO_WAIT   => $NO_WAIT,
                INIT      => $INIT,
                IPC       => $IPC,
                STACK     => $STACK,
                FORMAT    => $FORMAT,
                HOOKS     => [@HOOKS],
                LOADED    => $LOADED,
                POST_LOAD => [@POST_LOAD],
            };
        };
    }
}

sub pid { $PID }
sub tid { $TID }

sub hooks      { scalar @HOOKS }
sub post_loads { scalar @POST_LOAD }

sub init_done { $INIT ? 1 : 0 }

sub post_load {
    my $class = shift;
    my ($code) = @_;
    return $code->() if $LOADED;
    push @POST_LOAD => $code;
}

sub loaded {
    my $class = shift;

    return $LOADED if $LOADED || !@_;

    if ($_[0]) {
        $LOADED = 1;
        $_->() for @POST_LOAD;
    }

    return $LOADED
}

sub _init {
    $INIT  = [caller(1)];
    $STACK = Test::Stream::Stack->new;

    unless ($FORMAT) {
        my ($name, $source);
        if ($ENV{TS_FORMATTER}) {
            $name = $ENV{TS_FORMATTER};
            $source = "set by the 'TS_FORMATTER' environment variable";
        }
        else {
            $name = 'TAP';
            $source = 'default formatter';
        }

        my $mod = $name;
        $mod = "Test::Stream::Formatter::$mod"
            unless $mod =~ s/^\+//;

        my $file = pkg_to_file($mod);
        unless (eval { require $file; 1 }) {
            my $err = $@;
            my $line = "* COULD NOT LOAD FORMATTER '$name' ($source) *";
            my $border = '*' x length($line);
            die "\n\n  $border\n  $line\n  $border\n\n$err";
        }

        $FORMAT = $mod;
    }

    return unless $INC{'Test/Stream/IPC.pm'};
    $IPC = Test::Stream::IPC->init;
}

sub add_hook {
    my $class = shift;
    my ($code) = @_;
    my $rtype = reftype($code) || "";
    confess "End hooks must be coderefs"
        unless $code && $rtype eq 'CODE';
    push @HOOKS => $code;
}

sub stack {
    return $STACK if $INIT;
    _init();
    $STACK;
}

sub ipc {
    return $IPC if $INIT;
    _init();
    $IPC;
}

sub set_formatter {
    my $self = shift;
    croak "Global Formatter already set" if $FORMAT;
    $FORMAT = pop or croak "No formatter specified";
}

sub formatter {
    return $FORMAT if $INIT;
    _init();
    $FORMAT;
}

sub no_wait {
    my $class = shift;
    ($NO_WAIT) = @_ if @_;
    $NO_WAIT;
}

sub _ipc_wait {
    my $fail = 0;

    while (CAN_FORK) {
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
            # In older threads we cannot check if a thread had an error unless
            # we control it and its return.
            my $err = $t->can('error') ? $t->error : undef;
            next unless $err;
            my $tid = $t->tid();
            $fail++;
            chomp($err);
            warn "Thread $tid did not end cleanly: $err\n";
        }
    }

    return 0 unless $fail;
    return 255;
}

# Set the exit status
END { _set_exit() }
sub _set_exit {
    my $exit     = $?;
    my $new_exit = $exit;

    if ($PID != $$ or $TID != get_tid()) {
        $? = $exit;
        return;
    }

    my @hubs = $STACK ? $STACK->all : ();

    if (@hubs and $IPC and !$NO_WAIT) {
        local $?;
        my %seen;
        for my $hub (reverse @hubs) {
            my $ipc = $hub->ipc or next;
            next if $seen{$ipc}++;
            $ipc->waiting();
        }

        my $ipc_exit = _ipc_wait();
        $new_exit ||= $ipc_exit;
    }

    # None of this is necessary if we never got a root hub
    if(my $root = shift @hubs) {
        my $dbg = Test::Stream::DebugInfo->new(
            frame  => [__PACKAGE__, __FILE__, 0, 'Test::Stream::Context::END'],
            detail => 'Test::Stream::Context END Block finalization',
        );
        my $ctx = Test::Stream::Context->new(
            debug => $dbg,
            hub   => $root,
        );

        if (@hubs) {
            $ctx->diag("Test ended with extra hubs on the stack!");
            $new_exit  = 255;
        }

        unless ($root->no_ending) {
            local $?;
            $root->finalize($dbg) unless $root->state->ended;
            $_->($ctx, $exit, \$new_exit) for @HOOKS;
            $new_exit ||= $root->state->failed;
        }
    }

    $new_exit = 255 if $new_exit > 255;

    $? = $new_exit;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Sync - Primary Synchronization point, this is where global stuff
lives.

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

There is a need to synchronize some details for all tests that run. This
package stores these global objects. As little as possible is kept here, when
possible things should not be global.

=head1 SYNOPSIS

    use Test::Stream::Sync; # No Exports

    my $init  = Test::Stream::Sync->init_done;
    my $stack = Test::Stream::Sync->stack;
    my $ipc   = Test::Stream::Sync->ipc;

    Test::Stream::Sync->set_formatter($FORMATTER)
    my $formatter = Test::Stream::Sync->formatter;

=head1 CLASS METHODS

This class stores global instances of things. This package is NOT an object,
everything that uses it will get the same stuff.

=over 4

=item $bool = Test::Stream::Sync->init_done

This will return true if the stack and ipc instances have already been
initialized. It will return false if they have not.

=item $stack = Test::Stream::Sync->stack

This will return the global L<Test::Stream::Stack> instance. If this has not
yet been initialized it will be initialized now.

=item $ipc = Test::Stream::Sync->ipc

This will return the global L<Test::Stream::IPC> instance. If this has not yet
been initialized it will be initialized now.

=item $formatter = Test::Stream::Sync->formatter

This will return the global formatter class. This is not an instance. By
default the formatter is set to L<Test::Stream::Formatter::TAP>.

You can override this default using the C<TS_FORMATTER> environment variable.

Normally 'Test::Stream::Formatter::' is prefixed to the value in the
environment variable:

    $ TS_FORMATTER='TAP' perl test.t     # Use the Test::Stream::Formatter::TAP formatter
    $ TS_FORMATTER='Foo' perl test.t     # Use the Test::Stream::Formatter::Foo formatter

If you want to specify a full module name you use the '+' prefix:

    $ TS_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

=item Test::Stream::Sync->set_formatter($class)

Set the global formatter class. This can only be set once. B<Note:> This will
override anything specified in the 'TS_FORMATTER' environment variable.

=item $bool = Test::Stream::Sync->no_wait

=item Test::Stream::Sync->no_wait($bool)

This can be used to get/set the no_wait status. Waiting is turned on by
default. Waiting will cause the parent process/thread to wait until all child
processes and threads are finished before exiting. You will almost never want
to turn this off.

=item Test::Stream::Sync->add_hook(sub { ... })

This can be used to add a hook that is called after all testing is done. This
is too late to add additional results, the main use of this hook is to set the
exit code.

    Test::Stream::Sync->add_hook(
        sub {
            my ($context, $exit, \$new_exit) = @_;
            ...
        }
    );

The C<$context> passed in will be an instance of L<Test::Stream::Context>. The
C<$exit> argument will be the original exit code before anything modified it.
C<$$new_exit> is a reference to the new exit code. You may modify this to
change the exit code. Please note that C<$$new_exit> may already be different
from C<$exit>

=item Test::Stream::Sync->post_load(sub { ... })

Add a callback that will be called when Test::Stream is finished loading. This
means the callback will be run when Test::Stream is done loading all the
plugins in your use statement. If Test::Stream has already finished loading
then the callback will be run immedietly.

=item $bool = Test::Stream::Sync->loaded

=item Test::Stream::Sync->loaded($true)

Without arguments this will simply return the boolean value of the loaded flag.
If Test::Stream has finished loading this will be true, otherwise false. If a
true value is provided as an argument then this will set the flag to true, and
run all C<post_load> callbacks. The second form should B<ONLY> ever be used in
L<Test::Stream> or alternative loader modules.

=back

=head1 MAGIC

This package has an END block. This END block is responsible for setting the
exit code based on the test results. This end block also calls the hooks that
can be added to this package.

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

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
