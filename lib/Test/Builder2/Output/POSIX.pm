package Test::Builder2::Output::POSIX;

use strict;
use Mouse;

extends 'Test::Builder2::Output';

sub INNER_begin {
    my $self = shift;
    $self->out("Running $0\n");
}

sub INNER_result {
    my($self, $result) = @_;

    if( $result->passed ) {
        $self->out("PASS: @{[$result->description]}\n");
    }
    else {
        $self->out("FAIL: @{[$result->description]}\n");
    }

    return;
}

sub INNER_end {
}

1;
