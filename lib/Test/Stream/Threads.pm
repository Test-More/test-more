package Test::Stream::Threads;
use strict;
use warnings;

use Test::Stream::Capabilities qw/CAN_THREAD/;

BEGIN {
    if(CAN_THREAD) {
        # Threads are possible, so we need it to be dynamic.

        if ($INC{'threads.pm'}) {
            # Threads are already loaded, so we do not need to check if they
            # are loaded each time
            *USE_THREADS = sub() { 1 };
            *get_tid = sub { threads->tid() };
        }
        else {
            # :-( Need to check each time to see if they have been loaded.
            *USE_THREADS = sub { $INC{'threads.pm'} ? 1 : 0 };
            *get_tid = sub { $INC{'threads.pm'} ? threads->tid() : 0 };
        }
    }
    else {
        # No threads, not now, not ever!
        *USE_THREADS = sub() { 0 };
        *get_tid     = sub() { 0 };
    }
}

use Test::Stream::Exporter;
default_exports qw/get_tid USE_THREADS/;
no Test::Stream::Exporter;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Threads - Tools for using threads with Test::Stream.

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

Returns true if threads are enabled, false if they are not.

=item get_tid

This will return the id of the current thread when threads are enabled,
otherwise it returns 0.

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

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
