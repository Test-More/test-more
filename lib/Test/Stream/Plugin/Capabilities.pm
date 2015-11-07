package Test::Stream::Plugin::Capabilities;
use strict;
use warnings;

use Test::Stream::Capabilities;
use Test::Stream::Plugin;

use Carp qw/croak/;

sub load_ts_plugin {
    my $class = shift;
    my ($caller, @args) = @_;

    @args = (qw/CAN_THREAD CAN_FORK/) unless @args;

    for my $arg (@args) {
        croak "$arg is not a valid capabilties check"
            unless $arg =~ m/^CAN_/ && Test::Stream::Capabilities->can($arg);

        my $const = Test::Stream::Capabilities::get_const($arg);
        no strict 'refs';
        *{"$caller->[0]\::$arg"} = $const;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Capabilities - Import constants to check the capabilities
of the current system.

=head1 DESCRIPTION

Sometimes you want to know what capabilities the current system has. Checking
on these can sometimes be complicated or error prone. This tool provides
constants for some common capability checks.

=head1 SYNOPSIS

    use Test::Stream qw/... Capabilities/;

    if (CAN_THREAD) {
        ... Code that uses threads ...
    }

    if (CAN_FORK) {
        ... Code that forks ...
    }

    if (CAN_REALLY_FORK) {
        ... Code that requires true forking, but breaks with pseudo-fork ...
    }

=head1 CHECKS

See L<Test::Stream::Capabilities> for a list of checks, this plugin is a simple
wrapper around it.

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
