package Test::Builder2::Types;

use Test::Builder2::Mouse ();
use Test::Builder2::Mouse::Util qw(load_class);
use Test::Builder2::Mouse::Util::TypeConstraints;


=head1 NAME

Test::Builder2::Types - Mouse types used by Test::Builder2

=head1 SYNOPSIS

    use Test::Builder2::Types;

=head1 DESCRIPTION

This defines custom Mouse types used by Test::Builder2.

=head2 Types

=head3 Test::Buidler2::Positive_Int

An integer greater than or equal to zero.

=cut

subtype 'Test::Builder2::Positive_Int' => (
    as 'Int',
    where { defined $_ && $_ >= 0 },
);


=head3 Test::Builder2::Positive_NonZero_Int

An integer greater than zero.

=cut

subtype 'Test::Builder2::Positive_NonZero_Int' => (
    as 'Int',
    where { defined $_ && $_ > 0 },
);


=head3 Test::Builder2::LC_AlphaNumUs_Str

A lowercase string containing only alphanumerics & underscores.

=cut

subtype 'Test::Builder2::LC_AlphaNumUS_Str' => (
    as 'Str',
    where { defined $_ && /^[a-z_]+$/ },
);


=head3 Test::Builder2::LoadableClass

A class name.  It will be loaded.

=cut

subtype 'Test::Builder2::LoadableClass', as 'ClassName';
coerce 'Test::Builder2::LoadableClass', from 'Str', via { load_class($_); $_ };

no Test::Builder2::Mouse::Util::TypeConstraints;

1;
