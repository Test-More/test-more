package Test::Stream::DeepCheck::Check;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;

use Scalar::Util qw/blessed looks_like_number/;
use Carp qw/croak/;

use Test::Stream::HashBase(
    accessors => [qw/file start_line end_line/],
);

sub as_string { 'Custom DeepCheck' }

sub deep { 0 };

sub run { croak "unimplemented" }

sub post_check {}

sub check {
    my $self = shift;
    my ($got, $path, $state) = @_;

    my $recursive = $got && $self->deep;

    # If we have hit recursion we need to break out, do so with a passing
    # result, but add a hint to the summary.
    return Test::Stream::DeepCheck::Result->new(
        bool => 1,
        summary => [ '!RECURSION!', '!RECURSION!' ],
    ) if $recursive && $state->seen->{$got};

    $state->seen->{$got}++ if $recursive;
    my $res = $self->run(@_);
    $state->seen->{$got}-- if $recursive;

    my @add;
    my %seen = map { $_ => 1 } @{$res->diag};
    for my $check (@{$res->checks || []}) {
        next if $seen{$check}++;

        if (my $file = $check->{+FILE}) {
            my $start = $check->{+START_LINE};
            my $end   = $check->{+END_LINE};

            my $lines;
            if (defined($start) && defined($end)) {
                if ($start == $end) {
                    $lines = " line $start";
                }
                else {
                    $lines = " line $start -> $end";
                }
            }
            elsif (defined($start)) {
                $lines = " line $start";
            }
            elsif (defined($end)) {
                $lines = " line $end";
            }
            else {
                $lines = "";
            }

            my $msg = "- Check defined at $file$lines";
            next if $seen{$msg}++;

            unshift @add => $msg;
        }
    }

    unshift @{$res->diag} => @add;

    $self->post_check($res, @_);

    return $res;
}

1;
