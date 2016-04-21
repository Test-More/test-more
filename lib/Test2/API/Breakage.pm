package Test2::API::Breakage;
use strict;
use warnings;

our $VERSION = '1.302014_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

our @EXPORT_OK = qw{
    upgrade_suggested
    upgrade_required
    known_broken
};
use base 'Exporter';

sub upgrade_suggested {
    return (
        'Test::Exception'    => 0.43,
        'Data::Peek'         => 0.45,
        'circular::require'  => 0.12,
        'Test::Module::Used' => 0.2.5,
        'Test::Moose::More'  => 0.025,
        'Test::FITesque'     => 0.04,
        'autouse'            => 1.11,
    );
}

sub upgrade_required {
    return (
        'Test::SharedFork'        => 0.35,
        'Test::Builder::Clutch'   => 0.07,
        'Test::Dist::VersionSync' => 1.1.4,
        'Test::Modern'            => 0.012,
    );
}

sub known_broken {
    return (
        'Test::Aggregate'       => 0.373,
        'Test::Wrapper'         => 0.3.0,
        'Test::ParallelSubtest' => 0.05,
        'Test::Pretty'          => 0.32,
        'Test::More::Prefix'    => 0.005,
        'Net::BitTorrent'       => 0.052,
        'Test::Group'           => 0.20,
        'Test::Flatten'         => 0.11,
    );
}

1;

__END__


=pod

=encoding UTF-8

=head1 NAME

Test2::API::Breakage - What breaks at what version

=head1 DESCRIPTION

This module provides lists of modules that are broken, or have been broken in
the past, when upgrading L<Test::Builder> to use L<Test2>.

=head1 FUNCTIONS

These can be imported, or called as methods on the class.

=over 4

=item %mod_ver = upgrade_suggested()

=item %mod_ver = Test2::API::Breakage->upgrade_suggested()

This returns key/value pairs. The key is the module name, the value is the
version number. If the installed version of the module is at or below the
specified one then an upgrade would be a good idea, but not strictly necessary.

=item %mod_ver = upgrade_required()

=item %mod_ver = Test2::API::Breakage->upgrade_required()

This returns key/value pairs. The key is the module name, the value is the
version number. If the installed version of the module is at or below the
specified one then an upgrade is required for the module to work properly.

=item %mod_ver = known_broken()

=item %mod_ver = Test2::API::Breakage->known_broken()

This returns key/value pairs. The key is the module name, the value is the
version number. If the installed version of the module is at or below the
specified one then the module will not work. A newer version may work, but is
not tested or verified.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
