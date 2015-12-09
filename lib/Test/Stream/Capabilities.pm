package Test::Stream::Capabilities;
use strict;
use warnings;

use Config qw/%Config/;
use Carp qw/croak/;

{
    no warnings 'once';
    *CAN_REALLY_FORK = $Config{d_fork} ? sub() { 1 } : sub() { 0 };
    *CAN_FORK        = _can_fork()     ? sub() { 1 } : sub() { 0 };
    *CAN_THREAD      = _can_thread()   ? sub() { 1 } : sub() { 0 };
}

use Test::Stream::Exporter qw/import exports/;
exports qw/CAN_REALLY_FORK CAN_FORK CAN_THREAD/;
no Test::Stream::Exporter;

sub _can_fork {
    return 1 if $Config{d_fork};
    return 0 unless $^O eq 'MSWin32' || $^O eq 'NetWare';
    return 0 unless $Config{useithreads};
    return 0 unless $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/;

    my $thread_const = get_const('CAN_THREAD');

    return $thread_const->();
}

sub _can_thread {
    return 0 unless $] >= 5.008001;
    return 0 unless $Config{'useithreads'};

    # Threads are broken on perl 5.10.0 built with gcc 4.8+
    if ($] == 5.010000 && $Config{'ccname'} eq 'gcc' && $Config{'gccversion'}) {
        my @parts = split /\./, $Config{'gccversion'};
        return 0 if $parts[0] >= 4 && $parts[1] >= 8;
    }

    # Change to a version check if this ever changes
    return 0 if $INC{'Devel/Cover.pm'};
    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Capabilities - Check if the current system has various
capabilities.

=head1 SYNOPSIS

    use Test::Stream::Capabilities qw/CAN_FORK CAN_REALLY_FORK CAN_THREAD/;

    if (CAN_FORK) {
        my $pid = fork();
        ...
    }

    if (CAN_REALLY_FORK) {
        my $pid = fork();
        ...
    }

    if (CAN_THREAD) {
        threads->new(sub { ... });
    }

=head1 DESCRIPTION

This module will export requested constants which will always be a boolean true
or false.

=head1 AVAILABLE CHECKS

=over 4

=item CAN_FORK

True if this system is capable of true or psuedo-fork.

=item CAN_REALLY_FORK

True if the system can really fork. This will be false for systems where fork
is emulated.

=item CAN_THREAD

True if this system is capable of using threads.

=back

=head1 NOTES && CAVEATS

=over 4

=item 5.10.0

Perl 5.10.0 has a bug when compiled with newer gcc versions. This bug causes a
segfault whenever a new thread is launched. Test::Stream will attempt to detect
this, and note that the system is not capable of forking when it is detected.

=item Devel::Cover

Devel::Cover does not support threads. CAN_THREAD will return false if
Devel::Cover is loaded before the check is first run.

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

See F<http://dev.perl.org/licenses/>

=cut
