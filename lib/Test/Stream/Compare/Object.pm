package Test::Stream::Compare::Object;
use strict;
use warnings;

use Test::Stream::Util qw/try/;

use Test::Stream::Compare;
use Test::Stream::Compare::Meta;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/calls meta refcheck/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype blessed/;

sub init {
    my $self = shift;
    $self->{+CALLS} ||= [];
}

sub name { '<OBJECT>' }

sub meta_class  { 'Test::Stream::Compare::Meta' }
sub object_base { 'UNIVERSAL' }

sub verify {
    my $self = shift;
    my ($got) = @_;

    return 0 unless $got;
    return 0 unless ref($got);
    return 0 unless blessed($got);
    return 0 unless $got->isa($self->object_base);
    return 1;
}

sub add_prop {
    my $self = shift;
    $self->{+META} ||= $self->meta_class->new;
    $self->{+META}->add_prop(@_);
}

sub add_field {
    my $self = shift;
    $self->{+REFCHECK} ||= Test::Stream::Compare::Hash->new;

    croak "Underlying reference does not have fields"
        unless $self->{+REFCHECK}->can('add_field');

    $self->{+REFCHECK}->add_field(@_);
}

sub add_item {
    my $self = shift;
    $self->{+REFCHECK} ||= Test::Stream::Compare::Array->new;

    croak "Underlying reference does not have items"
        unless $self->{+REFCHECK}->can('add_item');

    $self->{+REFCHECK}->add_item(@_);
}

sub add_call {
    my $self = shift;
    my ($meth, $check, $name) = @_;
    $name ||= ref $meth ? '\&CODE' : $meth;
    push @{$self->{+CALLS}} => [$meth, $check, $name];
}

sub deltas {
    my $self = shift;
    my ($got, $convert, $seen) = @_;

    my @deltas;
    my $meta     = $self->{+META};
    my $refcheck = $self->{+REFCHECK};

    push @deltas => $meta->deltas(@_) if $meta;

    for my $call (@{$self->{+CALLS}}) {
        my ($meth, $check, $name)= @$call;

        $check = $convert->($check);

        my $exists = ref($meth) || $got->can($meth);
        my $val;
        my ($ok, $err) = try { $val = $exists ? $got->$meth : undef };

        if (!$ok) {
            push @deltas => $self->delta_class->new(
                verified  => undef,
                id        => [METHOD => $name],
                got       => undef,
                check     => $check,
                exception => $err,
            );
        }
        elsif ($exists) {
            push @deltas => $check->run([METHOD => $name], $val, $convert, $seen);
        }
        else {
            push @deltas => $self->delta_class->new(
                dne      => 'got',
                verified => undef,
                id       => [METHOD => $name],
                got      => undef,
                check    => $check,
            );
        }
    }

    push @deltas => $refcheck->deltas(@_) if $refcheck;

    return @deltas;
}

1;
