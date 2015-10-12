package Test::Stream::Compare::Scalar;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/item/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype blessed/;

sub init {
    my $self = shift;
    croak "'item' is a required attribute"
        unless $self->{+ITEM};

    $self->SUPER::init();
}

sub name     { '<SCALAR>' }
sub operator { '${...}' }

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;
    return 0 unless $got;
    return 0 unless ref($got);
    return 0 unless reftype($got) eq 'SCALAR';
    return 1;
}

sub deltas {
    my $self = shift;
    my %params = @_;
    my ($got, $convert, $seen) = @params{qw/got convert seen/};

    my $item = $self->{+ITEM};
    my $check = $convert->($item);

    return (
        $check->run(
            id      => ['SCALAR' => '$*'],
            got     => $$got,
            convert => $convert,
            seen    => $seen,
            exists  => 1,
        ),
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Scalar - Representation of a Scalar Ref in deep
comparisons

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

This is used in deep comparisons to represent a scalar reference.

=head1 SYNOPSIS

    my $sr = Test::Stream::Compare::Scalar->new(item => 'foo');

    is([\'foo'], $sr, "pass");
    is([\'bar'], $sr, "fail, different value");
    is(['foo'],  $sr, "fail, not a ref");

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
