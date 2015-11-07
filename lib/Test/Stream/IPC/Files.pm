package Test::Stream::IPC::Files;
use strict;
use warnings;

use base 'Test::Stream::IPC';

use Test::Stream::HashBase(
    accessors => [qw/tempdir event_id tid pid globals/],
);

use Scalar::Util qw/blessed/;
use File::Temp;
use Storable;
use File::Spec;

use Test::Stream::Util qw/try get_tid pkg_to_file/;

sub is_viable { 1 }

sub init {
    my $self = shift;

    my $tmpdir = File::Temp::tempdir(CLEANUP => 0);

    $self->abort_trace("Could not get a temp dir") unless $tmpdir;

    $self->{+TEMPDIR} = File::Spec->canonpath($tmpdir);

    print STDERR "\nIPC Temp Dir: $tmpdir\n\n"
        if $ENV{TS_KEEP_TEMPDIR};

    $self->{+EVENT_ID} = 1;

    $self->{+TID} = get_tid();
    $self->{+PID} = $$;

    $self->{+GLOBALS} = {};

    return $self;
}

sub hub_file {
    my $self = shift;
    my ($hid) = @_;
    my $tdir = $self->{+TEMPDIR};
    return File::Spec->canonpath("$tdir/HUB-$hid");
}

sub event_file {
    my $self = shift;
    my ($hid, $e) = @_;

    my $tempdir = $self->{+TEMPDIR};
    my $type = blessed($e) or $self->abort("'$e' is not a blessed object!");

    $self->abort("'$e' is not an event object!")
        unless $type->isa('Test::Stream::Event');

    my @type = split '::', $type;
    my $name = join('-', $hid, $$, get_tid(), $self->{+EVENT_ID}++, @type);

    return File::Spec->canonpath("$tempdir/$name");
}

sub add_hub {
    my $self = shift;
    my ($hid) = @_;

    my $hfile = $self->hub_file($hid);

    $self->abort_trace("File for hub '$hid' already exists")
        if -e $hfile;

    open(my $fh, '>', $hfile) or $self->abort_trace("Could not create hub file '$hid': $!");
    print $fh "$$\n" . get_tid() . "\n";
    close($fh);
}

sub drop_hub {
    my $self = shift;
    my ($hid) = @_;

    my $tdir = $self->{+TEMPDIR};
    my $hfile = $self->hub_file($hid);

    $self->abort_trace("File for hub '$hid' does not exist")
        unless -e $hfile;

    open(my $fh, '<', $hfile) or $self->abort_trace("Could not open hub file '$hid': $!");
    my ($pid, $tid) = <$fh>;
    close($fh);

    $self->abort_trace("A hub file can only be closed by the process that started it\nExpected $pid, got $$")
        unless $pid == $$;

    $self->abort_trace("A hub file can only be closed by the thread that started it\nExpected $tid, got " . get_tid())
        unless get_tid() == $tid;

    if ($ENV{TS_KEEP_TEMPDIR}) {
        rename($hfile, File::Spec->canonpath("$hfile.complete")) or $self->abort_trace("Could not rename file '$hfile' -> '$hfile.complete'");
    }
    else {
        unlink($hfile) or $self->abort_trace("Could not remove file for hub '$hid'");
    }

    opendir(my $dh, $tdir) or $self->abort_trace("Could not open temp dir!");
    for my $file (readdir($dh)) {
        next if $file =~ m{\.complete$};
        next unless $file =~ m{^$hid};
        $self->abort_trace("Not all files from hub '$hid' have been collected!");
    }
    closedir($dh);
}

sub send {
    my $self = shift;
    my ($hid, $e) = @_;

    my $tempdir = $self->{+TEMPDIR};
    my $global = $hid eq 'GLOBAL';
    my $hfile = $self->hub_file($hid);

    $self->abort("hub '$hid' is not available! Failed to send event!\n")
        unless $global || -f $hfile;

    my $file = $self->event_file($hid, $e);
    my $ready = File::Spec->canonpath("$file.ready");

    if ($global) {
        my $name = $ready;
        $name =~ s{^.*(GLOBAL)}{GLOBAL};
        $self->globals->{$name}++;
    }

    my ($ok, $err) = try {
        Storable::store($e, $file);
        rename($file, $ready) or $self->abort("Could not rename file '$file' -> '$ready'");
    };
    if (!$ok) {
        my $src_file = __FILE__;
        $err =~ s{ at \Q$src_file\E.*$}{};
        chomp($err);
        my $tid = get_tid();
        my $trace = $e->debug->trace;
        my $type = blessed($e);

        $self->abort(<<"        EOT");

*******************************************************************************
There was an error writing an event:
Destination: $hid
Origin PID:  $$
Origin TID:  $tid
Event Type:  $type
Event Trace: $trace
File Name:   $file
Ready Name:  $ready
Error: $err
*******************************************************************************

        EOT
    }

    return 1;
}

sub cull {
    my $self = shift;
    my ($hid) = @_;

    my $tempdir = $self->{+TEMPDIR};

    opendir(my $dh, $tempdir) or $self->abort("could not open IPC temp dir ($tempdir)!");

    my @out;
    my @files = sort readdir($dh);
    for my $file (@files) {
        next if $file =~ m/^\.+$/;
        next unless $file =~ m/^(\Q$hid\E|GLOBAL)-.*\.ready$/;
        my $global = $1 eq 'GLOBAL';
        next if $global && $self->globals->{$file}++;

        # Untaint the path.
        my $full = File::Spec->canonpath("$tempdir/$file");
        ($full) = ($full =~ m/^(.*)$/gs);

        my $obj = $self->read_event_file($full);

        # Do not remove global events
        unless ($global) {
            my $complete = File::Spec->canonpath("$full.complete");
            if ($ENV{TS_KEEP_TEMPDIR}) {
                rename($full, $complete) or $self->abort("Could not rename IPC file '$full', '$complete'");
            }
            else {
                unlink($full) or $self->abort("Could not unlink IPC file: $file");
            }
        }

        push @out => $obj;
    }

    closedir($dh);
    return @out;
}

sub read_event_file {
    my $self = shift;
    my ($file) = @_;

    my $obj = Storable::retrieve($file);
    $self->abort("Got an unblessed object: '$obj'")
        unless blessed($obj);

    unless ($obj->isa('Test::Stream::Event')) {
        my $pkg  = blessed($obj);
        my $mod_file = pkg_to_file($pkg);
        my ($ok, $err) = try { require $mod_file };

        $self->abort("Event has unknown type ($pkg), tried to load '$mod_file' but failed: $err")
            unless $ok;

        $self->abort("'$obj' is not a 'Test::Stream::Event' object")
            unless $obj->isa('Test::Stream::Event');
    }

    return $obj;
}

sub waiting {
    my $self = shift;
    require Test::Stream::Event::Waiting;
    $self->send(
        GLOBAL => Test::Stream::Event::Waiting->new(
            debug => Test::Stream::DebugInfo->new(frame => [caller()]),
        )
    );
    return;
}

sub DESTROY {
    my $self = shift;

    return unless defined $self->pid;
    return unless defined $self->tid;

    return unless $$        == $self->pid;
    return unless get_tid() == $self->tid;

    my $tempdir = $self->{+TEMPDIR};

    opendir(my $dh, $tempdir) or $self->abort("Could not open temp dir! ($tempdir)");
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        next if $file =~ m/\.complete$/;
        my $full = File::Spec->canonpath("$tempdir/$file");

        if ($file =~ m/^(GLOBAL|HUB-)/) {
            $full =~ m/^(.*)$/;
            $full = $1; # Untaint it
            next if $ENV{TS_KEEP_TEMPDIR};
            unlink($full) or $self->abort("Could not unlink IPC file: $full");
            next;
        }

        $self->abort("Leftover files in the directory ($full)!\n");
    }
    closedir($dh);

    if ($ENV{TS_KEEP_TEMPDIR}) {
        print STDERR "# Not removing temp dir: $tempdir\n";
        return;
    }

    rmdir($tempdir) or warn "Could not remove IPC temp dir ($tempdir)";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::IPC::Files - Temp dir + Files concurrency model.

=head1 DESCRIPTION

This is the default, and fallback concurrency model for L<Test::Stream>. This
sends events between processes and threads using serialized files in a
temporary directory. This is not particularily fast, but it works everywhere.

=head1 SYNOPSIS

    use Test::Stream::IPC::Files;
    use Test::Stream ...;

or

    use Test::Stream ..., 'IPC' => ['Files'];

or

    use Test::Stream ..., 'IPC' => ['+Test::Stream::IPC::Files'];

=head1 SEE ALSO

See L<Test::Stream::IPC> for methods.

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
