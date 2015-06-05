package Test::Stream::IPC;
use strict;
use warnings;

use Config;
use Carp qw/confess carp longmess/;

my @DRIVERS;

sub drivers {
    unless(@DRIVERS) {
        # Fallback to files
        require Test::Stream::IPC::Files;
        push @DRIVERS => 'Test::Stream::IPC::Files';
    }

    return @DRIVERS;
}

sub import {
    my $class = shift;

    if ($class eq __PACKAGE__) {
        Test::Stream::Context::TOP_HUB() if $INC{'Test/Stream/Context.pm'};
        return;
    }

    return unless $class->is_viable;

    push @DRIVERS => $class;

    return unless $INC{'Test/Stream/Context.pm'};

    if (Test::Stream::Context->PEEK_HUB) {
        carp "IPC Driver '$class' was loaded too late to be used by the root hub";
    }
    else {
        Test::Stream::Context::TOP_HUB() if $INC{'Test/Stream/Context.pm'};
    }
}

for my $meth (qw/send cull add_hub drop_hub waiting is_viable/) {
    no strict 'refs';
    *$meth = sub {
        my $thing = shift;
        confess "'$thing' did not define the required method '$meth'."
    };
}

# Print the error and call exit. We are not using 'die' cause this is a
# catastophic error that should never be caught. If we get here it
# means some serious shit has happened in a child process, the only way
# to inform the parent may be to exit false.

sub abort {
    my $class = shift;
    chomp(my ($msg) = @_);
    print STDERR "IPC Fatal Error: $msg\n";
    CORE::exit(255);
}

sub abort_trace {
    my $class = shift;
    chomp(my ($msg) = @_);
    print STDERR "IPC Fatal Error: $msg\n";
    $class->abort(longmess($msg));
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::IPC - Enable concurrency in Test::Stream.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 SYNOPSIS

    use Test::Stream::IPC

=head1 CLASS METHODS

=over 4

=item $class->import

This is a no-op when called on Test::Stream::IPC itself. For subclasses it will
set the subclass as the driver.

=item @drivers = $class->drivers

Obtain the list of drivers that have been loaded, in the order they were
loaded. If no driver has been loaded this will load and return
L<Test::Stream::IPC::Files>.

=item $class->abort($msg)

If an IPC encounters a fatal error it should use this. This will print the
message to STDERR with C<'IPC Fatal Error: '> prefixed to it, then it will
forcefully exit 255. IPC errors may occur in threads or processes other than
the main one, this method provides the best chance of the harness noticing the
error.

=item $class->abort_trace($msg)

This is the same as C<< $ipc->abort($msg) >> except that it uses
C<Carp::longmess> to add a stack trace to the message.

=back

=head1 LOADING DRIVERS

Test::Stream::IPC has an C<import()> method. All drivers inherit this import
method. This import method registers the driver with the main IPC module.

In most cases you just need to load the desired IPC driver to make it work. You
should load this driver as early as possible. A warning will be issued if you
load it too late for it to be effective.

    use Test::Stream::IPC::MyDriver;
    ...

=head1 WRITING DRIVERS

    package My::IPC::Driver;
    use strict;
    use warnings;

    use base 'Test::Stream::IPC';

    sub is_viable {
        return 0 if $^O eq 'win32'; # Will not work on windows.
        return 1;
    }

    sub add_hub {
        my $self = shift;
        my ($hid) = @_;

        ... # Make it possible to contact the hub
    }

    sub drop_hub {
        my $self = shift;
        my ($hid) = @_;

        ... # Nothing should try to reach the hub anymore.
    }

    sub send {
        my $self = shift;
        my ($hid, $e) = @_;

        ... # Send the event to the proper hub.
    }

    sub cull {
        my $self = shift;
        my ($hid) = @_;

        my @events = ...; # Here is where you get the events for the hub

        return @events;
    }

    sub waiting {
        my $self = shift;

        ... # Notify all listening procs and threads that the main
        ... # process/thread is waiting for them to finish.
    }

    1;

=head2 METHODS SUBCLASSES MUST IMPLEMENT

=over 4

=item $ipc->is_viable

This should return true if the driver works in the current environment. This
should return false if it does not.

=item $ipc->add_hub($hid)

This is used to alert the driver that a new hub is expecting events. The driver
should keep track of the process and thread ids, the hub should only be dropped
by the proc+thread that started it.

    sub add_hub {
        my $self = shift;
        my ($hid) = @_;

        ... # Make it possible to contact the hub
    }

=item $ipc->drop_hub($hid)

This is used to alert the driver that a hub is no longer accepting events. The
driver should keep track of the process and thread ids, the hub should only be
dropped by the proc+thread that started it (This is the drivers responsibility
to enforce).

    sub drop_hub {
        my $self = shift;
        my ($hid) = @_;

        ... # Nothing should try to reach the hub anymore.
    }

=item $ipc->send($hid, $event);

Used to send events from the current process/thread to the specified hub in its
process+thread.

    sub send {
        my $self = shift;
        my ($hid, $e) = @_;

        ... # Send the event to the proper hub.
    }

=item @events = $ipc->cull($hid)

Used to collect events that have been sent to the specified hub.

    sub cull {
        my $self = shift;
        my ($hid) = @_;

        my @events = ...; # Here is where you get the events for the hub

        return @events;
    }

=item $ipc->waiting()

This is called in the parent process when it is complete and waiting for all
child processes and threads to complete.

    sub waiting {
        my $self = shift;

        ... # Notify all listening procs and threads that the main
        ... # process/thread is waiting for them to finish.
    }

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

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
