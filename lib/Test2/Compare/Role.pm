package Test2::Compare::Role;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/blessed/;

use base 'Test2::Compare::Base';

our $VERSION = '1.302220';

use Test2::Util::HashBase qw/input/;

# Overloads '!' for us.
use Test2::Compare::Negatable;

sub init {
    my $self = shift;
    confess "input must be defined for 'Role' check" unless defined $self->{+INPUT};

    $self->SUPER::init(@_);
}

sub name {
    my $self = shift;
    my $in   = $self->{+INPUT};
    return "$in";
}

sub operator {
    my $self = shift;
    return '!role' if $self->{+NEGATE};
    return 'role';
}

sub verify {
    my $self   = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;
    return 0 unless eval { require Role::Tiny; 1 };

    my $input  = $self->{+INPUT};
    my $negate = $self->{+NEGATE};
    my $role   = Role::Tiny::does_role($got, $input);

    return !$role if $negate;
    return $role;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Compare::Role - Check if the value does the role.

=head1 DESCRIPTION

This is used to check if the got value does the expected role.

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<https://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item TOYAMA Nao E<lt>nanto@moon.email.ne.jpE<gt>

=back

=head1 COPYRIGHT

Copyright Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
