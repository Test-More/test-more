package Test::Stream::Compare::Hash;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/inref ending items order/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype/;

sub init {
    my $self = shift;

    if(my $ref = $self->{+INREF}) {
        croak "Cannot specify both 'inref' and 'items'" if $self->{+ITEMS};
        croak "Cannot specify both 'inref' and 'order'" if $self->{+ORDER};
        $self->{+ITEMS} = {%$ref};
        $self->{+ORDER} = [sort keys %$ref];
    }
    else {
        # Clone the ref to be safe
        $self->{+ITEMS} = $self->{+ITEMS} ? {%{$self->{+ITEMS}}} : {};
        $self->{+ORDER} ||= [sort keys %{$self->{+ITEMS}}];
    }
}

sub name { '<HASH>' }

sub verify {
    my $self = shift;
    my ($got) = @_;

    return 0 unless $got;
    return 0 unless ref($got);
    return 0 unless reftype($got) eq 'HASH';
    return 1;
}

sub add_field {
    my $self = shift;
    my ($name, $check) = @_;

    croak "field name is required"
        unless defined $name;

    croak "field '$name' has already been specified"
        if exists $self->{+ITEMS}->{$name};

    push @{$self->{+ORDER}} => $name;
    $self->{+ITEMS}->{$name} = $check;
}

sub deltas {
    my $self = shift;
    my ($got, $convert, $seen) = @_;

    # Short-cut if $got and $ref are the same reference
    if (my $ref = $self->{+INREF}) {
        return if $ref == $got;
    }

    my @deltas;
    my $items = $self->{+ITEMS};

    # Make a copy that we can munge as needed.
    my %fields = %$got;

    for my $key (@{$self->{+ORDER}}) {
        my $check  = $convert->($items->{$key});
        my $exists = exists $fields{$key};
        my $val    = delete $fields{$key};

        if ($exists) {
            push @deltas => $check->run([HASH => $key], $val, $convert, $seen);
        }
        elsif (!$check->isa('Test::Stream::Compare::DNE')) {
            push @deltas => $self->delta_class->new(
                dne      => 'got',
                verified => undef,
                id       => [HASH => $key],
                got      => undef,
                check    => $check,
            );
        }
    }

    # if items are left over, and ending is true, we have a problem!
    if($self->{+ENDING} && keys %fields) {
        for my $key (sort keys %fields) {
            push @deltas => $self->delta_class->new(
                dne      => 'check',
                verified => undef,
                id       => [HASH => $key],
                got      => $fields{$key},
                check    => undef,
            );
        }
    }

    return @deltas;
}

1;
