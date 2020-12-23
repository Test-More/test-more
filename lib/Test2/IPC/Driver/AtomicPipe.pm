package Test2::IPC::Driver::AtomicPipe;
use strict;
use warnings;

our $VERSION = '1.302184';

BEGIN { require Test2::IPC::Driver; our @ISA = qw(Test2::IPC::Driver) }

use Test2::Util::HashBase qw{global_file tid pid globals pipes};

use Scope::Guard;
use Scalar::Util qw/blessed/;
use File::Temp();
use Storable();
use File::Spec();
use POSIX();

use Storable qw/store_fd fd_retrieve/;
use Fcntl qw/LOCK_EX LOCK_SH LOCK_UN SEEK_END SEEK_SET/;

use Test2::Util qw/try get_tid pkg_to_file IS_WIN32 ipc_separator do_rename do_unlink try_sig_mask/;
use Test2::API qw/test2_ipc_set_pending/;

sub is_viable {
    eval { require Atomic::Pipe; Atomic::Pipe->VERSION('0.014'); 1 } or return 0;
    return 1;
}

sub init {
    my $self = shift;

    my ($fh, $filename) = File::Temp::tempfile(UNLINK => 0);
    close($fh);

    $self->abort_trace("Could not get a temp file") unless $filename;

    $self->{+GLOBAL_FILE} = File::Spec->canonpath($filename);

    $self->{+TID} = get_tid();
    $self->{+PID} = $$;

    $self->{+GLOBALS} = {};

    return $self;
}

sub add_hub {
    my $self = shift;
    my ($hid) = @_;

    $self->abort_trace("Pipe for hub '$hid' already exists")
        if $self->{+PIPES}->{$hid};

    my ($r, $w) = Atomic::Pipe->pair();

    # 1mb
    $w->resize_or_max(1 * 1024 * 1024);
    $r->blocking(0);

    my $file = $self->{+GLOBAL_FILE};
    open(my $g, '<', $file) or $self->abort("Could not open GLOBAL file '$file': $!");
    flock($g, LOCK_SH) or die "Could not lock: $!";
    seek($g, 0, SEEK_END);
    my $gi = -s $g;
    flock($g, LOCK_UN) or die "Could not unlock: $!";
    $g->blocking(0);

    $self->{+PIPES}->{$hid} = {
        pid => $$,
        tid => get_tid(),
        r   => $r,
        w   => $w,
        g   => $g,
        gi  => $gi,
    };

    return;
}

sub drop_hub {
    my $self = shift;
    my ($hid) = @_;

    my $pipe = delete $self->{+PIPES}->{$hid}
        or $self->abort_trace("Pipe for hub '$hid' does not exist");

    my $pid = $pipe->{pid};
    my $tid = $pipe->{tid};

    $self->abort_trace("A hub pipe can only be closed by the process that started it\nExpected $pid, got $$")
        unless $pid == $$;

    $self->abort_trace("A hub pipe can only be closed by the thread that started it\nExpected $tid, got " . get_tid())
        unless get_tid() == $tid;

#    $pipe->{w}->close();
#
#    my $rh = $pipe->{r};
#    $self->abort_trace("The pipe still has unread data") if <$rh>;
#
#    $pipe->{r}->close();
#
#    close($pipe->{g});

    return;
}

sub send {
    my $self = shift;
    my ($hid, $e, $global) = @_;

    return $self->send_global($hid, $e, $global) if $global;

    my $pipe = $self->{+PIPES}->{$hid};
    $self->abort(<<"    EOT") unless $pipe;
hub '$hid' is not available, failed to send event!

There was an attempt to send an event to a hub in a parent process or thread,
but that hub appears to be gone. This can happen if you fork, or start a new
thread from inside subtest, and the parent finishes the subtest before the
child returns.

This can also happen if the parent process is done testing before the child
finishes. Test2 normally waits automatically in the root process, but will not
do so if Test::Builder is loaded for legacy reasons.
    EOT

    my $data = Storable::freeze($e);
    $pipe->{w}->write_message($data);

    return 1;
}

sub send_global {
    my $self = shift;
    my ($hid, $e, $global) = @_;

    my $file = $self->{+GLOBAL_FILE};
    open(my $fh, '>>', $file) or $self->abort("Could not open GLOBAL file '$file': $!");

    flock($fh, LOCK_EX) or die "Could not lock: $!";
    seek($fh, 0, SEEK_END);
    my $gid = tell($fh);
    $e->{__global_id} = $gid;
    store_fd($e, $fh);
    flock($fh, LOCK_UN) or die "Could not unlock: $!";

    delete $e->{__global_id};
    $self->{+GLOBALS}->{$hid}->{$gid} = 1;

    return;
}

sub driver_abort {
    my $self = shift;
    my ($msg) = @_;

    eval { $self->send_global(0, {DRIVER_ABORT => $msg}); 1 } or warn $@;
}

sub cull {
    my $self = shift;
    my ($hid) = @_;

    my $pipe = $self->{+PIPES}->{$hid} or die "Could not find hub $hid";

    my @out;

    # If the global file has changed size, cull from it
    if ($pipe->{gi} < -s $pipe->{g}) {
        push @out => $self->_read_events($pipe->{g}, size => \($pipe->{gi}), clear_eof => 1, lock => 1);
    }

    while (my $msg = $pipe->{r}->read_message) {
        my $e = Storable::thaw($msg);
        push @out => $e;
    }

    for my $e (@out) {
        CORE::exit(255) if ref($e) eq 'HASH' && exists $e->{DRIVER_ABORT};

        $self->abort("Got an unblessed object: '$e'")
            unless blessed($e);

        next if $e->isa('Test2::Event');

        my $pkg      = blessed($e);
        my $mod_file = pkg_to_file($pkg);
        my ($ok, $err) = try { require $mod_file };

        $self->abort("Event has unknown type ($pkg), tried to load '$mod_file' but failed: $err")
            unless $ok;

        $self->abort("'$e' is not a 'Test2::Event' object")
            unless $e->isa('Test2::Event');
    }

    return @out;
}

sub _read_events {
    my $self = shift;
    my ($rh, %params) = @_;

    my @out;

    my $guard;
    if ($params{lock}) {
        flock($rh, LOCK_SH) or die "Could not lock: $!";
        $guard = Scope::Guard->new(sub { flock($rh, LOCK_UN) });
    }

    while (1) {
        my $pos = $params{clear_eof} ? tell($rh) : 0;

        my ($data, $ok, $err);
        {
            local $@;
            $ok  = eval { $data = fd_retrieve($rh); 1 };
            $err = $@;
        }

        if ($ok) {
            push @out => $data;
            next;
        }
        elsif ($err =~ m/Magic number checking on storable file failed/) {
            if ($params{clear_eof}) {
                seek($rh, $pos, SEEK_SET) or die "$!";
            }
            last;
        }
        else {
            $self->abort($err);
            last;
        }
    }

    ${$params{size}} = -s $rh if $params{size};
    flock($rh, LOCK_UN) or die "Could not unlock: $!"
        if $params{lock};

    $guard->dismiss() if $guard;

    return @out;
}

sub waiting {
    my $self = shift;
    require Test2::Event::Waiting;
    $self->send(
        GLOBAL => Test2::Event::Waiting->new(
            trace => Test2::EventFacet::Trace->new(frame => [caller()]),
        ),
        'GLOBAL'
    );
    return;
}

sub DESTROY {
    my $self = shift;

    return unless defined $self->pid;
    return unless defined $self->tid;

    return unless $$        == $self->pid;
    return unless get_tid() == $self->tid;

    unlink($self->{+GLOBAL_FILE}) if -f $self->{+GLOBAL_FILE};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::IPC::Driver::AtomicPipe - Use pipes for IPC

=head1 DESCRIPTION

This uses L<Atomic::Pipe> for IPC communication.

=head1 SYNOPSIS

    use Test2::IPC::Driver::AtomicPipe;

    # IPC is now enabled

=head1 SEE ALSO

See L<Test2::IPC::Driver> for methods.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2020 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
