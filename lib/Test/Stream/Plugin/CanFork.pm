package Test::Stream::Plugin::CanFork;
use strict;
use warnings;

use Test::Stream::Capabilities qw/CAN_FORK CAN_REALLY_FORK/;

use Test::Stream::Plugin;

sub load_ts_plugin {
    my $class = shift;
    my ($caller, %params) = @_;

    if ($params{real}) {
        return if CAN_REALLY_FORK;
    }
    else {
        return if CAN_FORK;
    }

    require Test::Stream::Context;
    my $ctx = Test::Stream::Context::context();
    $ctx->plan(0, "SKIP", "This test requires a perl capable of forking.");
    $ctx->release;
    exit 0;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::CanFork - Skip a test file unless the system supports
forking

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

It is fairly common to write tests that need to fork. Not all systems support
forking. This library does the hard work of checking if forking is supported on
the current system. If forking is not supported then this will skip all tests
and exit true.

=head1 SYNOPSIS

    use Test::Stream::Plugin::CanFork;

    ... Code that forks ...

or

    use Test::Stream::Plugin::CanFork real => 1;

    ... Code that requires true fork support (not emulated) ...


=head1 EXPLANATION

Checking if the current system supports forking is not simple, here is an
example of how to do it:

    use Config;

    sub CAN_FORK {
        return 1 if $Config{d_fork};

        # Some platforms use ithreads to mimick forking
        return 0 unless $^O eq 'MSWin32' || $^O eq 'NetWare';
        return 0 unless $Config{useithreads};
        return 0 unless $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/;

        # Threads are not reliable before 5.008001
        return 0 unless $] >= 5.008001;

        # Devel::Cover currently breaks with threads
        return 0 if $INC{'Devel/Cover.pm'};
        return 1;
    }

Duplicating this non-trivial code in all tests that need to fork is dumb. It is
easy to forget bits, or get it wrong. On top of these checks you also need to
tell the harness that no tests should run and why.

=head1 SEE ALSO

=over 4

=item L<Test::Stream::Plugin::CanThread>

Skip the test file if the system does not support threads.

=item L<Test::Stream>

Test::Stream::Plugin::CanFork uses L<Test::Stream> under the hood.

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
