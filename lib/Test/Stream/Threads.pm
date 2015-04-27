package Test::Stream::Threads;
use strict;
use warnings;

BEGIN {
    use Config;
    if( $Config{useithreads} && $INC{'threads.pm'} ) {
        eval q|
            sub get_tid { threads->tid() }
            sub USE_THREADS() { 1 }
            1;
        | || die $@;
    }
    else {
        eval q|
            sub get_tid() { 0 }
            sub USE_THREADS() { 0 }
            1;
        | || die $@;
    }
}

use Test::Stream::Exporter qw/default_exports import/;
default_exports qw/get_tid USE_THREADS/;
Test::Stream::Exporter->cleanup;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Threads - Tools for using threads with Test::Stream.

=head1 DESCRIPTION

This module provides some helpers for Test::Stream and Toolsets to use to
determine if threading is in place. In most cases you will not need to use this
module yourself.

=head1 SYNOPSIS

    use threads;
    use Test::Stream::Threads;

    if (USE_THREADS) {
        my $tid = get_tid();
    }

=head1 EXPORTS

=over 4

=item USE_THREADS

This is a constant, it is set to true when Test::Stream is aware of, and using, threads.

=item get_tid

This will return the id of the current thread when threads are enabled,
otherwise it returns 0.

=back

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
