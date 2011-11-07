package Test::Builder2::Formatter::POSIX;

use Test::Builder2::Mouse;

extends 'Test::Builder2::Formatter';

sub accept_stream_start {
    my $self  = shift;
    my $event = shift;

    $self->write(output => "Running $0\n");

    return;
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

sub accept_result {
    my($self, $result) = @_;

    my $type = $type_map{$result->type};
    $self->write(output => "$type: @{[$result->name]}\n");

    return;
}

1;
