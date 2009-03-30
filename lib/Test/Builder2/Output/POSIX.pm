package Test::Builder2::Output::POSIX;

use strict;
use Mouse;

extends 'Test::Builder2::Output';

sub INNER_begin {
    my $self = shift;
    $self->out("Running $0\n");
}

# Map Result types to POSIX types
my %type_map = (
    pass        => "PASS",
    fail        => "FAIL",
    todo_pass   => 'XPASS',
    todo_fail   => 'XFAIL',
    skip        => 'UNTESTED',
    todo_skip   => 'UNTESTED',
);

sub INNER_result {
    my($self, $result) = @_;

    my $type = $type_map{$result->type};
    $self->out("$type: @{[$result->description]}\n");

    return;
}

sub INNER_end {
}

1;
