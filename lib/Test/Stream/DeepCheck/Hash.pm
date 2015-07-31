package Test::Stream::DeepCheck::Hash;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/fields order/],
);

use Test::Stream::DeepCheck qw/stringify convert fail_table/;
use Scalar::Util qw/reftype/;
use List::Util qw/max/;
use Carp qw/croak/;

sub deep { 1 };

sub as_string { "A 'HASH' reference" }

sub init {
    my $self = shift;

    $self->{+FIELDS} ||= {};

    croak "'fields' must be a hashref"
        unless reftype($self->{+FIELDS}) eq 'HASH';

    $self->{+ORDER} ||= [sort keys %{$self->{+FIELDS}}];
}

sub add_field {
    my $self = shift;
    my ($name, $check) = @_;

    croak "field '$name' is already defined"
        if $self->{+FIELDS}->{$name};

    croak "second argument to add_field must be a hashref of convert() args"
        unless $check && ref $check && reftype($check) eq 'HASH';

    push @{$self->{+ORDER}} => $name;
    $self->{+FIELDS}->{$name} = $check;
}

sub run {
    my $self = shift;
    my ($got, $path, $state) = @_;

    my @diag;
    my @summary = (stringify($got), "A 'HASH' reference");
    my $res = Test::Stream::DeepCheck::Result->new(
        checks  => [$self],
        diag    => \@diag,
        summary => \@summary,
    );

    # Make sure we are looking at a hash
    my $type = reftype($got) || "";
    unless ($type eq 'HASH') {
        @diag = (
            "     \$got$path: $summary[0]",
            "\$expected$path: $summary[1]",
        );
        return $res->fail;
    }

    my $fail = $self->failures(@_);

    return $res->pass unless @$fail;

    my $msg = "Hash check failure";
    $msg = "\$var${path}: $msg" if $path;
    push @diag => $msg;

    # Build our failure diag
    push @diag => fail_table(
        id => 'KEY',
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

    my $order  = $self->{+ORDER};
    my $fields = $self->{+FIELDS};

    my $nest = $path || '->';

    my %seen;
    my @keys = grep { !$seen{$_}++ } @$order, sort keys %$got;

    my @fail;
    for my $key (@keys) {
        my $exp_e = exists $fields->{$key};
        my $val_e = exists $got->{$key};
        my $val = $val_e ? $got->{$key} : undef;

        my $res;

        if ($exp_e && $val_e) {
            my $exp = convert(%{$fields->{$key}}, state => $state);
            $res = $exp->check($val, "$nest\{$key}", $state);
            $res->set_deep(1) if $exp->deep;
        }
        elsif($exp_e) { # No value
            my $check = convert(%{$fields->{$key}}, state => $state);
            my @summary = ("Does Not Exist", stringify($check));
            my @diag = (
                "     \$got$nest\{$key}: $summary[0]",
                "\$expected$nest\{$key}: $summary[1]",
            );

            $res = Test::Stream::DeepCheck::Result->new(
                checks  => [$check],
                bool    => 0,
                diag    => \@diag,
                summary => \@summary,
            );
        }
        else { # Nothing expected
            next unless $state->strict;

            my @summary = (stringify($val), "Does Not Exist");
            my @diag = (
                "     \$got$nest\{$key}: $summary[0]",
                "\$expected$nest\{$key}: $summary[1]",
            );

            $res = Test::Stream::DeepCheck::Result->new(
                checks  => [$self],
                bool    => 0,
                diag    => \@diag,
                summary => \@summary,
            );
        }

        next if $res->bool;

        $res->set_id($key);
        push @fail => $res;
        $res->push_check($self);
    }

    return \@fail;
}

1;
