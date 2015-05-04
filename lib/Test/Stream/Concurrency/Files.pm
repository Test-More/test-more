package Test::Stream::Concurrency::Files;
use strict;
use warnings;

use Test::Stream::HashBase(
    base => 'Test::Stream::Concurrency',
    accessors => [qw/tempdir event_id tid pid/]
);

use File::Temp;
use Storable;

use Carp qw/confess/;
use Test::Stream::Util qw/try/;

use Test::Stream::Threads;

# I am not yet aware of any platforms on which this does not work.
sub is_viable { 1 }

sub init {
    my $self = shift;

    my $tmpdir = File::Temp::tempdir(CLEANUP => 0);
    confess "Could not get a temp dir" unless $tmpdir;

    if ($^O eq 'VMS') {
        require VMS::Filespec;
        $tmpdir = VMS::Filespec::unixify($tmpdir);
    }

    $self->{+TEMPDIR} = $tmpdir;

    $self->{+TID} = get_tid();
    $self->{+PID} = $$;

    return $self;
}

sub send {
    my $self = shift;
    my %params = @_;

    my $orig = join '-', @{$params{orig}};
    my $dest = join '-', @{$params{dest}};
    my $events = $params{events};

    my $route = "$dest-$orig";

    my $tempdir = $self->{+TEMPDIR};

    for my $event (@$events) {
        next unless $event;

        # First write the file, then rename it so that it is not read before it is ready.
        my $name =  $tempdir . "/$route-" . ($self->{+EVENT_ID}++);
        my ($ok, $err) = try { Storable::store($event, $name) };
        if (!$ok) {
            my $file = __FILE__;
            $err =~ s{ at \Q$file\E.*$}{};
            chomp($err);
            print STDERR <<"            EOT";

*******************************************************************************
There was an error writing an event:
$err

This usually means you let the parent process exit before the child process was
done sending events. You can probably fix this error by adding a call to wait()
at the end of your test script.
*******************************************************************************

            EOT
            print STDOUT "\nnot ok - This is to poison the TAP stream so that the harness catches this error.\n";
            exit 255;
        }
        rename($name, "$name.ready") || confess "Could not rename file '$name' -> '$name.ready'";
    }
}

sub cull {
    my $self = shift;
    my $prefix = join '-', @_;

    my $tempdir = $self->{+TEMPDIR};

    opendir(my $dh, $tempdir) || confess "could not open temp dir ($tempdir)!";

    my @out;
    my @files = sort readdir($dh);
    for my $file (@files) {
        next if $file =~ m/^\.+$/;
        next unless $file =~ m/^\Q$prefix\E-.*\.ready$/;

        # Untaint the path.
        my $full = "$tempdir/$file";
        ($full) = ($full =~ m/^(.*)$/gs);

        my $obj = Storable::retrieve($full);
        confess "Empty event object found '$full'" unless $obj;

        if ($ENV{TEST_KEEP_TMP_DIR}) {
            rename($full, "$full.complete")
                || confess "Could not rename file '$full', '$full.complete'";
        }
        else {
            unlink($full) || die "Could not unlink file: $file";
        }

        push @out => $obj;
    }

    closedir($dh);
    return @out;
}

sub DESTROY {
    my $self = shift;

    return unless defined $self->pid;
    return unless defined $self->tid;

    return unless $$        == $self->pid;
    return unless get_tid() == $self->tid;

    my $tempdir = $self->{+TEMPDIR};

    if ($ENV{TEST_KEEP_TMP_DIR}) {
        print STDERR "# Not removing temp dir: $tempdir\n";
        return;
    }

    opendir(my $dh, $tempdir) || confess "Could not open temp dir! ($tempdir)";
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        next if $file =~ m/\.complete$/;
        die "Unculled event! You ran tests in a child process, but never pulled them in!\n";
    }
    closedir($dh);

    return if $ENV{TEST_KEEP_TMP_DIR};

    rmdir($tempdir) || warn "Could not remove temp dir ($tempdir)";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Concurrency::Files - Temp dir + Files concurrency model.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head2 BACKWARDS COMPATABILITY SHIM

By default, loading Test-Stream will block Test::Builder and related namespaces
from loading at all. You can work around this by loading the compatability shim
which will populate the Test::Builder and related namespaces with a
compatability implementation on demand.

    use Test::Stream::Shim;
    use Test::Builder;
    use Test::More;

B<Note:> Modules that are experimenting with Test::Stream should NOT load the
shim in their module files. The shim should only ever be loaded in a test file.


=head1 DESCRIPTION

This is the default, and fallback concurrency model for L<Test::Stream>. This
sends events between processes and threads using serialized files in a
temporary directory. This is not particularily fast, but it works everywhere.

=head1 SYNOPSIS

    use Test::Stream concurrency => 'Test::Stream::Concurrency::Files';

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
