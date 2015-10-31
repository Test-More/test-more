package Test::Stream::Compare::Number;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/input/],
);

sub name {
    my $self = shift;
    my $in = $self->{+INPUT};
    return '<UNDEF>' unless defined $in;
    return $in;
}

sub operator {
    my $self = shift;

    return '' unless @_;
    my ($got) = @_;

    return '' if defined($self->{+INPUT}) xor defined($got);
    return '==';
}

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;

    my $input = $self->{+INPUT};
    return !defined($got) unless defined $input;
    return 0 unless defined($got);

    my @warnings;
    my $out;
    {
        local $SIG{__WARN__} = sub { push @warnings => @_ };
        $out = $input == $got;
    }

    for my $warn (@warnings) {
        if ($warn =~ m/numeric/) {
            $out = 0;
            next; # This warning won't help anyone.
        }
        warn $warn;
    }

    return $out;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Number - Compare 2 values as numbers

=head1 DESCRIPTION

This is used to compare 2 numbers. This makes an exception for undef, if both
sides are undef it will pass.

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
