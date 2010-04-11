#!/usr/bin/perl -w

use strict;
use warnings;

use Test::More;

{
    package My::Formatter;
    use Test::Builder2::Mouse;

    extends 'Test::Builder2::Formatter';

    has ['begin_called', 'result_called', 'end_called'] =>
        is      => 'rw',
        isa     => 'Int',
        default => 0
    ;

    sub INNER_begin {
        my $self = shift;
        $self->begin_called( $self->begin_called() + 1 );
    }

    sub INNER_result {
        my $self = shift;
        $self->result_called( $self->result_called() + 1 );
    }

    sub INNER_end {
        my $self = shift;
        $self->end_called( $self->end_called() + 1 );
    }

    sub check {
        my $self = shift;
        my($begin, $result, $end, $name) = @_;

        ::is $self->begin_called, $begin,         "begin  - $name";
        ::is $self->result_called, $result,       "result - $name";
        ::is $self->end_called, $end,             "end    - $name";
    }
}


my $formatter = My::Formatter->new;
is $formatter->has_begun, 0;
is $formatter->has_ended, 0;

$formatter->result;
$formatter->check(0, 1, 0, "result() before begin()");

$formatter->begin;
$formatter->check(1, 1, 0, "begin()");
is $formatter->has_begun, 1;

$formatter->begin;
$formatter->check(1, 1, 0, "begin() again");

$formatter->result;
$formatter->check(1, 2, 0, "Another result()");

$formatter->end;
$formatter->check(1, 2, 1, "end()");
is $formatter->has_ended, 1;

$formatter->end;
$formatter->check(1, 2, 1, "end() again");

ok !eval { $formatter->result; 1; }, "result() after end()";
like $@, qr/^\Qresult() called after end()/;


done_testing();
