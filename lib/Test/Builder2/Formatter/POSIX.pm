package Test::Builder2::Formatter::POSIX;

use strict;
use Test::Builder2::Mouse;

extends 'Test::Builder2::Formatter';

sub INNER_begin {
    my $self = shift;
    $self->write(output => "Running $0\n");
}

# Map Result types to POSIX types
my %type_map = (
    pass        => "PASS",
    fail        => "FAIL",
    todo_pass   => 'XPASS',
    todo_fail   => 'XFAIL',
    skip_pass   => 'UNTESTED',
    todo_skip   => 'UNTESTED',
);

sub INNER_result {
    my($self, $result) = @_;

    my $type = $type_map{$result->type};
    $self->write(output => "$type: @{[$result->description]}\n");

    return;
}

sub INNER_end {
}

1;
