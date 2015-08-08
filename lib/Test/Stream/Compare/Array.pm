package Test::Stream::Compare::Array;
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
        my $order = $self->{+ORDER} = [];
        my $items = $self->{+ITEMS} = {};
        for (my $i = 0; $i < @$ref; $i++) {
            push @$order => $i;
            $items->{$i} = $ref->[$i];
        }
    }
    else {
        $self->{+ITEMS} ||= {};
        $self->{+ORDER} ||= [sort { $a <=> $b } keys %{$self->{+ITEMS}}];
    }
}

sub name { '<ARRAY>' }

sub verify {
    my $self = shift;
    my ($got) = @_;

    return 0 unless $got;
    return 0 unless ref($got);
    return 0 unless reftype($got) eq 'ARRAY';
    return 1;
}

sub top_index {
    my $self = shift;
    my @order = @{$self->{+ORDER}};

    while(@order) {
        my $idx = pop @order;
        next if ref $idx;
        return $idx;
    }

    return undef; # No indexes
}

sub add_item {
    my $self = shift;
    my $check = pop;
    my ($idx) = @_;

    my $top = $self->top_index;
    croak "elements must be added in order!"
        if $top && $idx && $idx <= $top;

    $idx = defined($top) ? $top + 1 : 0
        unless defined($idx);

    push @{$self->{+ORDER}} => $idx;
    $self->{+ITEMS}->{$idx} = $check;
}

sub add_filter {
    my $self = shift;
    my ($code) = @_;
    croak "A single coderef is required"
        unless $code && ref $code && reftype($code) eq 'CODE';

    push @{$self->{+ORDER}} => $code;
}

sub deltas {
    my $self = shift;
    my ($got, $convert, $seen) = @_;

    # Short-cut if $got and $ref are the same reference
    if (my $ref = $self->{+INREF}) {
        return if $ref == $got;
    }

    my @deltas;
    my $state = 0;
    my @order = @{$self->{+ORDER}};
    my $items = $self->{+ITEMS};

    # Make a copy that we can munge as needed.
    my @list = @$got;

    while (@order) {
        my $idx = shift @order;
        my $overflow = 0;
        my $val;

        # We have a filter, not an index
        if (ref($idx)) {
            @list = $idx->(@list);
            next;
        }

        confess "Internal Error: Stacks are out of sync (state > idx)"
            if $state > $idx + 1;

        while ($state <= $idx) {
            $state++;
            $overflow = !@list;
            $val = shift @list;
        }

        confess "Internal Error: Stacks are out of sync (state != idx + 1)"
            unless $state == $idx + 1;

        my $check = $convert->($items->{$idx});

        if ($overflow) {
            push @deltas => $self->delta_class->new(
                dne      => 'got',
                verified => undef,
                id       => [ARRAY => $idx],
                got      => undef,
                check    => $check,
            );
        }
        else {
            push @deltas => $check->run([ARRAY => $idx], $val, $convert, $seen);
        }
    }

    # if items are left over, and ending is true, we have a problem!
    if($self->{+ENDING} && @list) {
        while (@list) {
            my $item = shift @list;
            push @deltas => $self->delta_class->new(
                dne      => 'check',
                verified => undef,
                id       => [ARRAY => $state++],
                got      => $item,
                check    => undef,
            );
        }
    }

    return @deltas;
}

 1;
