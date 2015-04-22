package Test::Stream::Concurrency::Files;
use strict;
use warnings;

use Test::Stream::HashBase(
    accessors => [qw/tempdir event_id/]
);

use base 'Test::Stream::Concurrency';

use File::Temp;
use Storable;

use Carp qw/confess/;
use Test::Stream::Util qw/try/;

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
        my ($ret, $err) = try { Storable::store($event, $name) };
        # Temporary to debug an error on one cpan-testers box
        unless ($ret) {
            require Data::Dumper;
            confess(Data::Dumper::Dumper({ error => $err, event => $event}));
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

sub cleanup {
    my $self = shift;

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
