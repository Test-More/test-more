package Test::Builder::NoOutput;

use strict;
use warnings;

use base qw(Test::Builder);


=head1 NAME

Test::Builder::NoOutput - A subclass of Test::Builder which prints nothing

=head1 SYNOPSIS

    use Test::Builder::NoOutput;

    my $tb = Test::Builder::NoOutput->new;

    ...test as normal...

    my $output = $tb->read;

=head1 DESCRIPTION

This is a subclass of Test::Builder which traps all its output.
It is mostly useful for testing Test::Builder.

=head3 read

    my $output = $tb->read;

Returns all the output (including failure and todo output) collected
so far.  It is destructive, each call to read clears the output
buffer.

=cut

my $Output = '';

my $Test = __PACKAGE__->new;

sub create {
    my $class = shift;
    my $test = $class->SUPER::create(@_);

    $test->output           (\$Output);
    $test->failure_output   (\$Output);
    $test->todo_output      (\$Output);

    return $test;
}

sub read {
    my $self = shift;

    my $out = $Output;

    $Output = '';

    return $out;
}

1;
