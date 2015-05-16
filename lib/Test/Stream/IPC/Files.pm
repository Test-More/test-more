package Test::Stream::IPC::Files;
use strict;
use warnings;

use Test::Stream::Threads;
use Scalar::Util qw/blessed/;

my $IS_VMS;
BEGIN {
    $IS_VMS = 1 if $^O eq 'VMS';
    require VMS::Filespec if $IS_VMS;
}

use base 'Test::Stream::IPC';

use Test::Stream::HashBase(
    accessors => [qw/tempdir event_id tid pid globals/],
);

use File::Temp;
use Storable;

use Scalar::Util qw/blessed/;

use Test::Stream::Util qw/try/;

sub is_viable { 1 }

sub init {
    my $self = shift;

    my $tmpdir = File::Temp::tempdir(CLEANUP => 0);
    $self->abort_trace("Could not get a temp dir") unless $tmpdir;

    $tmpdir = VMS::Filespec::unixify($tmpdir) if $IS_VMS;

    $self->{+TEMPDIR}  = $tmpdir;

    print STDERR "\nIPC Temp Dir: $tmpdir\n\n"
        if $ENV{TS_KEEP_TEMPDIR};

    $self->{+EVENT_ID} = 1;

    $self->{+TID} = get_tid();
    $self->{+PID} = $$;

    $self->{+GLOBALS} = {};

    return $self;
}

sub add_hub {
    my $self = shift;
    my ($hid) = @_;

    my $tdir = $self->{+TEMPDIR};
    my $hfile = "$tdir/$hid";

    $hfile = VMS::Filespec::unixify($hfile) if $IS_VMS;

    $self->abort_trace("File for hub '$hid' already exists")
        if -e $hfile;

    open(my $fh, '>', $hfile) || $self->abort_trace("Could not create hub file '$hid': $!");
    print $fh "$$\n" . get_tid() . "\n";
    close($fh);
}

sub drop_hub {
    my $self = shift;
    my ($hid) = @_;

    my $tdir = $self->{+TEMPDIR};
    my $hfile = "$tdir/$hid";

    $hfile = VMS::Filespec::unixify($hfile) if $IS_VMS;

    $self->abort_trace("File for hub '$hid' does not exist")
        unless -e $hfile;

    open(my $fh, '<', $hfile) || $self->abort_trace("Could not open hub file '$hid': $!");
    my ($pid, $tid) = <$fh>;
    close($fh);

    $self->abort_trace("A hub file can only be closed by the process that started it\nExpected $pid, got $$")
        unless $pid == $$;

    $self->abort_trace("A hub file can only be closed by the thread that started it\nExpected $tid, got " . get_tid())
        unless get_tid() == $tid;

    if ($ENV{TS_KEEP_TEMPDIR}) {
        rename($hfile, "$hfile.complete") || $self->abort_trace("Could not rename file '$hfile' -> '$hfile.complete'");
    }
    else {
        unlink($hfile) || $self->abort_trace("Could not remove file for hub '$hid'");
    }

    opendir(my $dh, $tdir) || $self->abort_trace("Could not open temp dir!");
    for my $file (readdir($dh)) {
        next if $file =~ m{\.complete$};
        next unless $file =~ m{^$hid};
        $self->abort_trace("Not all files from hub '$hid' have been collected!");
        last;
    }
    closedir($dh);
}

sub send {
    my $self = shift;
    my ($hid, $e) = @_;

    my $tempdir = $self->{+TEMPDIR};

    my $global = $hid eq 'GLOBAL';

    $self->abort("hub '$hid' is not available! Failed to send event!\n")
        unless $global || -f "$tempdir/$hid";

    my $name = join('-', $hid, $$, get_tid(), $self->{+EVENT_ID}++, blessed($e));
    my $file = "$tempdir/$name";

    $self->globals->{"$name.ready"}++ if $global;

    my ($ok, $err) = try {
        Storable::store($e, $file);
        rename($file, "$file.ready") || die "Could not rename file '$file' -> '$file.ready'\n";
    };
    if (!$ok) {
        my $file = __FILE__;
        $err =~ s{ at \Q$file\E.*$}{};
        chomp($err);
        my $tid = get_tid();
        my $ehid = $e->context->hid;
        my $type = blessed($e);
        my $trace = $e->context->trace;

        $self->abort(<<"        EOT");

*******************************************************************************
There was an error writing an event:
Destination: $hid
Origin PID:  $$
Origin TID:  $tid
Origin HID:  $ehid
Event Type:  $type
Event Trace: $trace
Error: $err
*******************************************************************************

        EOT
    }
}

sub cull {
    my $self = shift;
    my ($hid) = @_;

    my $tempdir = $self->{+TEMPDIR};

    opendir(my $dh, $tempdir) || $self->abort("could not open IPC temp dir ($tempdir)!");

    my @out;
    my @files = sort readdir($dh);
    for my $file (@files) {
        next if $file =~ m/^\.+$/;
        next unless $file =~ m/^(\Q$hid\E|GLOBAL)-.*\.ready$/;
        my $global = $1 eq 'GLOBAL';
        next if $global && $self->globals->{$file}++;

        # Untaint the path.
        my $full = "$tempdir/$file";
        ($full) = ($full =~ m/^(.*)$/gs);

        my $obj = Storable::retrieve($full);
        $self->abort("Empty event object recieved") unless $obj;
        $self->abort("Event '$obj' has unknown type! Did you forget to load the event package in the parent process?")
            unless $obj->isa('Test::Stream::Event');

        # Do not remove global events
        unless ($global) {
            if ($ENV{TS_KEEP_TEMPDIR}) {
                rename($full, "$full.complete")
                    || warn "Could not rename IPC file '$full', '$full.complete'\n";
            }
            else {
                unlink($full) || warn "Could not unlink IPC file: $file\n";
            }
        }

        push @out => $obj;
    }

    closedir($dh);
    return @out;
}

sub waiting {
    my $self = shift;
    # TODO: This should send a global 'waiting' event.
    return;
}

sub DESTROY {
    my $self = shift;

    return unless defined $self->pid;
    return unless defined $self->tid;

    return unless $$        == $self->pid;
    return unless get_tid() == $self->tid;

    my $tempdir = $self->{+TEMPDIR};

    if ($ENV{TS_KEEP_TEMPDIR}) {
        print STDERR "# Not removing temp dir: $tempdir\n";
        return;
    }

    opendir(my $dh, $tempdir) || $self->abort("Could not open temp dir! ($tempdir)");
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        next if $file =~ m/\.complete$/;
        if ($file =~ m/^GLOBAL/) {
            next if $ENV{TS_KEEP_TEMPDIR};
            unlink("$tempdir/$file") || warn "Could not unlink IPC file: $file";
            next;
        }

        $self->abort("Leftover files in the directory!\n");
    }
    closedir($dh);

    return if $ENV{TS_KEEP_TEMPDIR};

    rmdir($tempdir) || warn "Could not remove IPC temp dir ($tempdir)";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::IPC::Files - Temp dir + Files concurrency model.

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

This is the default, and fallback concurrency model for L<Test::Stream>. This
sends events between processes and threads using serialized files in a
temporary directory. This is not particularily fast, but it works everywhere.

=head1 SYNOPSIS

    use Test::Stream::IPC::Files;

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
