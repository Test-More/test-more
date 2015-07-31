package Test::Stream::DeepCheck::Meta;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/checks/],
);

use Test::Stream::DeepCheck qw/stringify convert fail_table/;
use Test::Stream::Util qw/try/;
use Scalar::Util qw/reftype blessed/;
use List::Util qw/max/;
use Carp qw/croak/;

sub deep { 1 };

sub as_string { "<Meta Checks>" }

sub init {
    my $self = shift;

    $self->{+CHECKS} ||= [];

    croak "'checks' must be an arrayref"
        unless reftype($self->{+CHECKS}) eq 'ARRAY';
}

sub add_prop {
    my $self = shift;
    my ($prop, $check) = @_;

    croak "'$prop' is not a known property"
        unless $self->can("get_prop_$prop");

    croak "second argument to add_prop must be a hashref of convert() args"
        unless $check && ref $check && reftype($check) eq 'HASH';

    push @{$self->{+CHECKS}} => [$prop, $check];
}

sub run {
    my $self = shift;
    my ($got, $path, $state) = @_;

    my @diag;
    my @summary = (stringify($got), $self->as_string);
    my $res = Test::Stream::DeepCheck::Result->new(
        checks  => [$self],
        diag    => \@diag,
        summary => \@summary,
    );

    my $fail = $self->failures(@_);

    return $res->pass unless @$fail;

    my $msg = "Meta check failure";
    $msg = "\$var${path}: $msg" if $path;
    push @diag => $msg;

    # Build our failure diag
    push @diag => fail_table(
        id => 'meta',
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

    my $checks = $self->{+CHECKS};

    my @fail;
    for my $set (@$checks) {
        my ($name, $check) = @$set;
        my $meth = "get_prop_$name";

        my $exp = convert(%$check, state => $state);
        my $val;
        my ($ok, $e) = try { $val = $self->$meth($got) };

        my $res;
        if (!$ok) {
            chomp($e);
            my @summary = (stringify("<EXCEPTION> $e"), stringify($exp));
            my @diag = (
                "     \$got$path <$name>: $summary[0]",
                "\$expected$path <$name>: $summary[1]",
            );

            $res = Test::Stream::DeepCheck::Result->new(
                checks  => [$exp],
                bool    => 0,
                diag    => \@diag,
                summary => \@summary,
            );
        }
        else {
            $res = $exp->check($val, "$path <$name>", $state);
            $res->set_deep(1) if $exp->deep;
        }

        next if $res->bool;

        $res->set_id($name);
        push @fail => $res;
        $res->push_check($self);
    }

    return \@fail;
}

sub get_prop_blessed { blessed($_[1]) }

sub get_prop_reftype { reftype($_[1]) }

sub get_prop_this { $_[1] }

sub get_prop_size {
    my $self = shift;
    my ($it) = @_;

    my $type = reftype($it) || '';

    return scalar @$it      if $type eq 'ARRAY';
    return scalar keys %$it if $type eq 'HASH';
    return undef;
}

1;
