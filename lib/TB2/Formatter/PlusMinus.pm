package TB2::Formatter::PlusMinus;

use TB2::Mouse;

extends 'TB2::Formatter';

sub handle_test_end {
    my $self  = shift;
    my $event = shift;

    $self->write(output => "\n");

    return;
}

sub handle_result {
    my($self, $result) = @_;

    my $out = $result->is_fail ? "-" : "+";
    $self->write(output => $out);

    return;
}

1;
