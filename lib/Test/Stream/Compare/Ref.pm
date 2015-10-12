package Test::Stream::Compare::Ref;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/input/],
);

use Test::Stream::Util qw/render_ref rtype/;
use Scalar::Util qw/reftype refaddr/;
use Carp qw/croak/;

sub init {
    my $self = shift;

    croak "'input' is a required attribute"
        unless $self->{+INPUT};

    croak "'input' must be a reference, got '" . $self->{+INPUT} . "'"
        unless ref $self->{+INPUT};

    $self->SUPER::init();
}

sub operator { '==' }

sub name { render_ref($_[0]->{+INPUT}) };

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;

    my $in = $self->{+INPUT};
    return 0 unless ref $in;
    return 0 unless ref $got;

    my $in_type = rtype($in);
    my $got_type = rtype($got);

    return 0 unless $in_type eq $got_type;

    # Don't let overloading mess with us.
    return refaddr($in) == refaddr($got);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Ref - Ref comparison

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

Used to compare 2 refs in a deep comparison.

=head1 SYNOPSIS

    my $ref = {};
    my $check = Test::Stream::Compare::Ref->new(input => $ref);

    # Passes
    is( [$ref], [$check], "The array contains the exact ref we want" );

    # Fails, they both may be empty hashes, but we are looking for a specific
    # reference.
    is( [{}], [$check], "This will fail");

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
