package Test::Stream::Capabilities;
use strict;
use warnings;

use Config;

sub import {
    my $class = shift;
    my $caller = caller;

    for my $check (@_) {
        die "'$check' is not a known capability"
            unless $check =~ m/^CAN_/ && $class->can("$check");

        my $const = get_const($check);
        no strict 'refs';
        *{"$caller\::$check"} = $const;
    }
}

my %LOOKUP;
sub get_const {
    my $check = shift;

    unless ($LOOKUP{$check}) {
        my $bool = __PACKAGE__->$check;
        $LOOKUP{$check} = sub() { $bool };
    }

    return $LOOKUP{$check};
}

sub CAN_FORK {
    return 1 if $Config{d_fork};
    return 0 unless $^O eq 'MSWin32' || $^O eq 'NetWare';
    return 0 unless $Config{useithreads};
    return 0 unless $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/;

    my $thread_const = get_const('CAN_THREAD');

    return $thread_const->();
}

sub CAN_THREAD {
    return 0 unless $] >= 5.008001;
    return 0 unless $Config{'useithreads'};

    # Change to a version check if this ever changes
    return 0 if $INC{'Devel/Cover.pm'};

    return 1 unless $] == 5.010000;

    require File::Temp;
    require File::Spec;

    my $perl = File::Spec->rel2abs($^X);
    my ($fh, $fn) = File::Temp::tempfile();
    print $fh <<'    EOT';
        BEGIN { print STDERR "# Checking for thread segfaults\n# " }
        use threads;
        my $t = threads->create(sub { 1 });
        $t->join;
        print STDERR "Threads appear to work\n";
        exit 0;
    EOT
    close($fh);

    return !system(qq{"$perl" "$fn"});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Capabilities - Check if the current system has various
capabilities.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 SYNOPSIS

    use Test::Stream::Capabilities qw/CAN_FORK CAN_THREAD/;

    if (CAN_FORK) {
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

=item CAN_THREAD

True if this system is capable of using threads.

=back

=head1 NOTES && CAVEATS

=over 4

=item 5.10.0

On perl 5.10.0 there is an extra check that launches a new perl interpreter to
ensure that threads do not cause segfaults. This is here because some 5.10.0
installations on newer systems have a segfault in threads bug.

On windows and other systems that use fork emulation via threads this check is
also run for CHECK_FORK.

The main issue with this is that it is slow.

=item Devel::Cover

Devel::Cover does not support threads. CHECK_THREADS will return false if
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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
