package Test::Stream::DeepCheck::Object;
use strict;
use warnings;

use Test::Stream::DeepCheck::Result;
use Test::Stream::DeepCheck::Check;
use Test::Stream::DeepCheck::Meta;
use Test::Stream::DeepCheck::Hash;
use Test::Stream::DeepCheck::Array;

use Test::Stream::HashBase(
    base      => 'Test::Stream::DeepCheck::Check',
    accessors => [qw/meta refcheck calls/],
);

use Test::Stream::DeepCheck qw/stringify convert fail_table/;
use Test::Stream::Util qw/try/;
use Scalar::Util qw/reftype blessed/;
use List::Util qw/max/;
use Carp qw/croak/;

sub deep        { 1 }
sub error_type  { 'Object' }
sub as_string   { "An object" }
sub meta_class  { 'Test::Stream::DeepCheck::Meta' }
sub object_base { 'UNIVERSAL' }

sub init {
    my $self = shift;

    $self->{+CALLS} ||= [];

    croak "'calls' must be an array reference (got: " . $self->{+CALLS} . ")"
        unless reftype($self->{+CALLS}) eq 'ARRAY';
}

sub add_item {
    my $self = shift;

    $self->{+REFCHECK} ||= Test::Stream::DeepCheck::Array->new;

    my $refcheck = $self->{+REFCHECK};
    croak "Can only add items to objects that are blessed array references"
        unless $refcheck && $refcheck->isa('Test::Stream::DeepCheck::Array');

    $refcheck->add_item(@_);
}

sub add_field {
    my $self = shift;

    $self->{+REFCHECK} ||= Test::Stream::DeepCheck::Hash->new(
        file       => $self->{+FILE},
        start_line => $self->{+START_LINE},
        end_line   => $self->{+END_LINE},
    );

    my $refcheck = $self->{+REFCHECK};
    croak "Can only add fields to objects that are blessed hash references"
        unless $refcheck && $refcheck->isa('Test::Stream::DeepCheck::Hash');

    $refcheck->add_field(@_);
}

sub add_call {
    my $self = shift;
    my ($meth, $check, $name) = @_;

    croak "second argument to add_call must be a hashref of convert() args"
        unless $check && ref $check && reftype($check) eq 'HASH';

    push @{$self->{+CALLS}} => [$meth, $check, $name];
}

sub add_prop {
    my $self = shift;
    $self->{+META} ||= $self->meta_class->new(
        file       => $self->{+FILE},
        start_line => $self->{+START_LINE},
        end_line   => $self->{+END_LINE},
    );
    $self->{+META}->add_prop(@_);
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

    # Make sure we are looking at an object
    unless (blessed($got) && $got->isa($self->object_base)) {
        @diag = (
            "     \$got$path: $summary[0]",
            "\$expected$path: $summary[1]",
        );
        return $res->fail;
    }

    my $refcheck = $self->{+REFCHECK};
    my $meta     = $self->{+META};

    my $ofail = $self->failures(@_);
    my $rfail = $refcheck ? $refcheck->failures(@_) : [];
    my $mfail = $meta     ? $meta->failures(@_)     : [];

    if ($refcheck) {
        my $wrap = $refcheck->isa('Test::Stream::DeepCheck::Hash') ? ['{', '}'] : ['[', ']'];
        for my $r (@$rfail) {
            my $id = $r->id;
            $r->set_id(join "", $wrap->[0], $id, $wrap->[1]);
        }
    }
    if ($meta) {
        for my $m (@$mfail) {
            my $id = $m->id;
            $m->set_id(join "", '<', $id, '>');
        }
    }

    my $fail = [ @$mfail, @$ofail, @$rfail ];

    return $res->pass unless @$fail;

    my $msg = $self->error_type . " check failure";
    $msg = "\$var${path}: $msg" if $path;
    push @diag => $msg;

    # Build our failure diag
    push @diag => fail_table(
        id => 'check',
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

    my $calls = $self->{+CALLS};

    my ($nest, $point);
    if ($path) {
        $nest = '';
        $point = '->';
    }
    else {
        $nest = '->';
        $point = '';
    }

    my @fail;
    for my $set (@$calls) {
        my ($meth, $check, $name) = @$set;
        $name ||= $meth;

        my $exp = convert(%$check, state => $state);
        my $val;
        my ($ok, $e) = try { $val = $got->$meth };

        my $res;
        if (!$ok) {
            chomp($e);
            my @summary = (stringify("<EXCEPTION> $e"), stringify($exp));
            my @diag = (
                "     \$got$nest$point$name(): $summary[0]",
                "\$expected$nest$point$name(): $summary[1]",
            );

            $res = Test::Stream::DeepCheck::Result->new(
                checks  => [$exp],
                bool    => 0,
                diag    => \@diag,
                summary => \@summary,
            );
        }
        else {
            $res = $exp->check($val, "$nest$point$name()", $state);
            $res->set_deep(1) if $exp->deep;
        }

        next if $res->bool;

        $res->set_id("$name()");
        push @fail => $res;
        $res->push_check($self);
    }

    return \@fail;
}

1;
