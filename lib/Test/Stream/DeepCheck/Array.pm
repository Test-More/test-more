package Test::Stream::DeepCheck::Array;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/items strict_end filters/],
);

use Test::Stream::DeepCheck qw/stringify convert fail_table/;
use Scalar::Util qw/reftype/;
use List::Util qw/max/;
use Carp qw/croak confess/;

sub as_string { "An 'ARRAY' reference" }

sub deep { 1 };

sub init {
    my $self = shift;

    $self->{+ITEMS} ||= {};

    croak "'items' must be a hashref with integers for keys"
        unless reftype($self->{+ITEMS}) eq 'HASH';
}

sub add_filter {
    my $self = shift;
    my ($filter) = @_;

    croak "Filters must be code references"
        unless $filter && ref $filter && reftype $filter eq 'CODE';

    $self->{+FILTERS} ||= [];

    push @{$self->{+FILTERS}} => $filter;
}

sub add_item {
    my $self = shift;

    my $items = $self->{+ITEMS};

    my ($idx, $check);
    if (@_ == 1) {
        $idx = keys %$items ? max(keys %$items) + 1 : 0;
        ($check) = @_;
    }
    else {
        ($idx, $check) = @_;
    }

    croak "index '$idx' is already defined"
        if $items->{$idx};

    croak "last/only argument to add_field must be a hashref of convert() args"
        unless $check && ref $check && reftype($check) eq 'HASH';

    $items->{$idx} = $check;
}

sub run {
    my $self = shift;
    my ($got, $path, $state) = @_;

    my @diag;
    my @summary = (stringify($got), "An 'ARRAY' reference");
    my $res = Test::Stream::DeepCheck::Result->new(
        checks  => [$self],
        diag    => \@diag,
        summary => \@summary,
    );

    # Make sure we are looking at an array
    my $type = reftype($got) || "";
    unless ($type eq 'ARRAY') {
        @diag = (
            "     \$got$path: $summary[0]",
            "\$expected$path: $summary[1]",
        );
        return $res->fail;
    }

    my $fail = $self->failures(@_);

    return $res->pass unless @$fail;

    my $msg = "Array check failure";
    $msg = "\$var${path}: " if $path;
    push @diag => $msg;

    # Build our failure diag
    push @diag => fail_table(
        id => 'IDX',
        res => $fail,
    );

    for my $r (@$fail) {
        next unless $r->deep;
        push @diag => "", @{$r->diag};
    }

    return $res->fail;
}

sub failures {
    my $self = shift;
    my ($got, $path, $state) = @_;
    my $strict = $state->strict;

    my $strict_end = $self->{+STRICT_END};

    my $nest = $path || '->';
    my $filters = $self->{+FILTERS};
    my $items   = $self->{+ITEMS};
    my $top     = keys %$items;

    my @filtered = @$got;
    if ($filters) {
        for my $filter (@$filters) {
            @filtered = $filter->(@filtered);
        }
    }

    my $count = ($strict || $strict_end) ? max($top, scalar @filtered) : $top;

    my @fail;
    for my $idx (0 .. ($count - 1)) {
        my $exp_e = exists $items->{$idx};
        my $val_e = exists $filtered[$idx];

        next unless $strict || $exp_e || $idx >= $top;

        my $res;
        if ($exp_e && $val_e) {
            my $exp = convert(%{$items->{$idx}}, state => $state);
            $res = $exp->check($filtered[$idx], "$nest\[$idx]", $state);
            $res->set_deep(1) if $exp->deep;
        }
        elsif ($val_e) {
            my @summary = (stringify($filtered[$idx]), "Does Not Exist");
            my @diag = (
                "     \$got$nest\[$idx]: $summary[0]",
                "\$expected$nest\[$idx]: $summary[1]",
            );

            $res = Test::Stream::DeepCheck::Result->new(
                checks  => [$self],
                bool    => 0,
                diag    => \@diag,
                summary => \@summary,
            );
        }
        elsif($exp_e) {
            my $check = convert(%{$items->{$idx}}, state => $state);
            my @summary = ("Does Not Exist", stringify($check));
            my @diag = (
                "     \$got$nest\[$idx]: $summary[0]",
                "\$expected$nest\[$idx]: $summary[1]",
            );

            $res = Test::Stream::DeepCheck::Result->new(
                checks  => [$check],
                bool    => 0,
                diag    => \@diag,
                summary => \@summary,
            );
        }
        else {
            confess "This should not happen! Please report this as a bug, include the full stack trace.";
        }

        next if $res->bool;

        $res->set_id($idx);
        push @fail => $res;
        $res->push_check($self);
    }

    return \@fail;
}

1;
