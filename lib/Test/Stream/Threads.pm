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

use Test::Stream::Exporter;
exports qw/get_tid USE_THREADS/;

1;

__END__

=head1 NAME

Test::Stream::Threads - Helper Test::Builder uses when threaded.

=head1 DESCRIPTION

Helper Test::Builder uses when threaded.

=head1 SYNOPSYS

    use threads;
    use Test::Stream::Threads;

    share(...);
    lock(...);

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

Most of this code was pulled out ot L<Test::Builder>, written by Schwern and
others.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
