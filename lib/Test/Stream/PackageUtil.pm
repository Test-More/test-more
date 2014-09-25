package Test::Stream::PackageUtil;
use strict;
use warnings;

sub confess { require Carp; goto &Carp::confess }

my @SLOTS = qw/HASH SCALAR ARRAY IO FORMAT CODE/;
my %SLOTS = map {($_ => 1)} @SLOTS;

sub import {
    my $caller = caller;
    no strict 'refs';
    *{"$caller\::package_sym"}       = \&package_sym;
    *{"$caller\::package_purge_sym"} = \&package_purge_sym;
    1;
}

sub package_sym {
    my ($pkg, $slot, $name) = @_;
    confess "you must specify a package" unless $pkg;
    confess "you must specify a symbol type" unless $slot;
    confess "you must specify a symbol name" unless $name;
    
    confess "'$slot' is not a valid symbol type! Valid: " . join(", ", @SLOTS)
        unless $SLOTS{$slot};

    no warnings 'once';
    no strict 'refs';
    return *{"$pkg\::$name"}{$slot};
}

sub package_purge_sym {
    my ($pkg, @pairs) = @_;

    for(my $i = 0; $i < @pairs; $i += 2) {
        my $purge = $pairs[$i];
        my $name  = $pairs[$i + 1];

        confess "'$purge' is not a valid symbol type! Valid: " . join(", ", @SLOTS)
            unless $SLOTS{$purge};

        no strict 'refs';
        local *GLOBCLONE = *{"$pkg\::$name"};
        undef *{"$pkg\::$name"};
        for my $slot (@SLOTS) {
            next if $slot eq $purge;
            *{"$pkg\::$name"} = *GLOBCLONE{$slot} if defined *GLOBCLONE{$slot};
        }
    }
}

1;

__END__

=encoding utf8

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

=over 4

=item Test::Stream

=item Test::Tester2

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

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
