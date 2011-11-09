package Test::Builder2::Formatter::PlusMinus;

use Test::Builder2::Mouse;

extends 'Test::Builder2::Formatter';

sub accept_test_end {
    my $self  = shift;
    my $event = shift;

    $self->write(output => "\n");

    return;
}

sub accept_result {
    my($self, $result) = @_;

    my $out = $result->is_fail ? "-" : "+";
    $self->write(output => $out);

    return;
}

1;
