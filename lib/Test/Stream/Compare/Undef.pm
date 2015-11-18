package Test::Stream::Compare::Undef;
use strict;
use warnings;

use Carp qw/confess/;

use Test::Stream::Compare();
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/negate/],
);

sub name { '<UNDEF>' }

sub operator {
    my $self = shift;

    return 'IS NOT' if $self->{+NEGATE};
    return 'IS';
}

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;

    return !defined($got) unless $self->{+NEGATE};
    return defined($got);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Undef - Check that something is undefined

=head1 DESCRIPTION

Make sure something is undefined in a comparison. You can also check that
something is defined.

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
