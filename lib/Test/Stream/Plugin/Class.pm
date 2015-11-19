package Test::Stream::Plugin::Class;
use strict;
use warnings;

use Test::Stream::Plugin qw/import/;

use Test::Stream::Util qw/pkg_to_file/;

sub load_ts_plugin {
    my $class = shift;
    my ($caller, $load) = @_;

    die "No module specified for 'Class' plugin at $caller->[1] line $caller->[2].\n"
        unless $load;

    my $file = pkg_to_file($load);
    my $ok = eval qq|# line $caller->[2] "$caller->[1]"\nrequire \$file; 1|;
    die $@ unless $ok;

    no strict 'refs';
    *{$caller->[0] . '::CLASS'} = \$load;
    *{$caller->[0] . '::CLASS'} = sub { $load };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Class - Plugin for loading and aliasing the package you
are testing.

=head1 DESCRIPTION

This plugin lets you designate a class as the class you are testing. The plugin
will load the class, and provide shortcuts for accessing it. Other plugins can
also make use of the exports to be smarter.

=head1 SYNOPSIS

    use Test::Stream Class => ['Package::You::Are::Testing'];

    # You can access the class name using either the $CLASS variable, or the
    # CLASS() function.
    can_ok(CLASS(), qr/foo bar/);
    isa_ok($CLASS,  'Package::Parent');

=head1 EXPORTS

=over 4

=item $class = CLASS()

This function returns the class name.

=item $CLASS

This package variable contains the class name.

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
