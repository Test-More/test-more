package Test::Stream::DeepCheck::Regex;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/pattern negate/],
);

use Test::Stream::DeepCheck qw/stringify deeptype/;
use Carp qw/croak/;

sub as_string { '$_ =~ ' . stringify(shift->{+PATTERN}) }

sub init {
    my $self = shift;
    croak "'pattern' is a required attribute"
        unless $self->{+PATTERN};

    croak "'pattern' must be a regex"
        unless deeptype($self->{+PATTERN}) eq 'REGEXP';
}

sub run {
    my $self = shift;
    my ($got, $path, $state) = @_;
    my $pattern = $self->{+PATTERN};

    if (!defined($got)) {
        my @summary = (stringify($got), stringify($pattern));
        my @diag = ("Undefined value used in pattern check");

        return Test::Stream::DeepCheck::Result->new(
            bool    => $self->{+NEGATE},
            checks  => [$self],
            summary => \@summary,
            diag    => \@diag,
        );
    }

    my @summary = (stringify($got), stringify($pattern));
    my @diag = ("\$got$path: $summary[0]");
    my $res = Test::Stream::DeepCheck::Result->new(
        checks  => [$self],
        summary => \@summary,
        diag    => \@diag,
    );

    if ($self->{+NEGATE}) {
        push @diag => "matches: $summary[1]";
        return $res->fail unless $got !~ $pattern;
    }
    else {
        push @diag => "doesn't match: $summary[1]";
        return $res->fail unless $got =~ $pattern;
    }

    $res->set_diag([]);
    return $res->pass;
}

1;
