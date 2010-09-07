package Test::Builder2::Mouse::TypeRegistry;
use Test::Builder2::Mouse::Util::TypeConstraints;

sub import {
    warn "Test::Builder2::Mouse::TypeRegistry is deprecated, please use Test::Builder2::Mouse::Util::TypeConstraints instead.";

    shift @_;
    unshift @_, 'Test::Builder2::Mouse::Util::TypeConstraints';
    goto \&Test::Builder2::Mouse::Util::TypeConstraints::import;
}

sub unimport {
    warn "Test::Builder2::Mouse::TypeRegistry is deprecated, please use Test::Builder2::Mouse::Util::TypeConstraints instead.";

    shift @_;
    unshift @_, 'Test::Builder2::Mouse::Util::TypeConstraints';
    goto \&Test::Builder2::Mouse::Util::TypeConstraints::unimport;
}

1;

__END__


=head1 NAME

Test::Builder2::Mouse::TypeRegistry - (DEPRECATED)

=head1 DESCRIPTION

Test::Builder2::Mouse::TypeRegistry is deprecated. Use Test::Builder2::Mouse::Util::TypeConstraints instead.

=cut
