package Mouse::TypeRegistry;
use Mouse::Util::TypeConstraints;

sub import {
    warn "Mouse::TypeRegistry is deprecated, please use Mouse::Util::TypeConstraints instead.";

    shift @_;
    unshift @_, 'Mouse::Util::TypeConstraints';
    goto \&Mouse::Util::TypeConstraints::import;
}

sub unimport {
    warn "Mouse::TypeRegistry is deprecated, please use Mouse::Util::TypeConstraints instead.";

    shift @_;
    unshift @_, 'Mouse::Util::TypeConstraints';
    goto \&Mouse::Util::TypeConstraints::unimport;
}

1;

__END__


=head1 NAME

Mouse::TypeRegistry - (DEPRECATED)

=head1 DESCRIPTION

Mouse::TypeRegistry is deprecated. Use Mouse::Util::TypeConstraints instead.

=cut
