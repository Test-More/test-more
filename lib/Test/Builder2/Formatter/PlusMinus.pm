package Test::Builder2::Formatter::PlusMinus;

use Test::Builder2::Mouse;

extends 'Test::Builder2::Formatter';

sub INNER_begin {}

sub INNER_result {
    my($self, $result) = @_;

    my $out = $result->is_fail ? "-" : "+";
    $self->write(output => $out);

    return;
}

sub INNER_end {
    my $self = shift;

    $self->write(output => "\n");
}


1;
