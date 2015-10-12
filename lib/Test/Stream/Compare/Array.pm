package Test::Stream::Compare::Array;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/inref ending items order/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype looks_like_number/;

sub init {
    my $self = shift;

    if(my $ref = $self->{+INREF}) {
        croak "Cannot specify both 'inref' and 'items'" if $self->{+ITEMS};
        croak "Cannot specify both 'inref' and 'order'" if $self->{+ORDER};
        croak "'inref' must be an array reference, got '$ref'" unless reftype($ref) eq 'ARRAY';
        my $order = $self->{+ORDER} = [];
        my $items = $self->{+ITEMS} = {};
        for (my $i = 0; $i < @$ref; $i++) {
            push @$order => $i;
            $items->{$i} = $ref->[$i];
        }
    }
    else {
        $self->{+ITEMS} ||= {};
        croak "All indexes listed in the 'items' hashref must be numeric"
            if grep { !looks_like_number($_) } keys %{$self->{+ITEMS}};

        $self->{+ORDER} ||= [sort { $a <=> $b } keys %{$self->{+ITEMS}}];
        croak "All indexes listed in the 'order' arrayref must be numeric"
            if grep { !(looks_like_number($_) || (ref($_) && reftype($_) eq 'CODE')) } @{$self->{+ORDER}};
    }

    $self->SUPER::init();
}

sub name { '<ARRAY>' }

sub verify {
    my $self = shift;
    my %params = @_;

    return 0 unless $params{exists};
    my $got = $params{got} || return 0;
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
        unless @_ == 1 && $code && ref $code && reftype($code) eq 'CODE';

    push @{$self->{+ORDER}} => $code;
}

sub deltas {
    my $self = shift;
    my %params = @_;
    my ($got, $convert, $seen) = @params{qw/got convert seen/};

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

        push @deltas => $check->run(
            id      => [ARRAY => $idx],
            convert => $convert,
            seen    => $seen,
            exists  => !$overflow,
            $overflow ? () : (got => $val),
        );
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Array - Internal representation of an array comparison.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This module is an internal representation of an array for comparison purposes.

=head1 METHODS

=over 4

=item $ref = $arr->inref()

If the instance was constructed from an actual array, this will have the
reference to that array.

=item $bool = $arr->ending

=item $arr->set_ending($bool)

Set this to true if you would like to fail when the array being validated has
more items than the check. That is if you check indexes 0-3, but the array
recieved has values for indexes 0-4, it will fail and list that last item in
the array as unexpected. If this is false then it is assumed you do not care
about extra items.

=item $hashref = $arr->items()

=item $arr->set_items($hashref)

This gives you the hashref of C<< key => val >> pairs to be checked in the
array. This is a hashref so that indexes can be skipped if desired.

B<Note:> that there is no validation when using C<set_items>, it is better to
use the C<add_item> interface.

=item $arrayref = $arr->order()

=item $arr->set_order($arrayref)

This gives you an arrayref of all indexes that will be checked, in order.

B<Note:> that there is no validation when using C<set_order>, it is better to
use the C<add_item> interface.

=item $name = $arr->name()

Always returns the string C<< "<ARRAY>" >>.

=item $bool = $arr->verify(got => $got, exists => $bool)

Check if C<$got> is an array reference or not.

=item $idx = $arr->top_index()

Get the topmost index that gets checked. This will return undef if there are no
items, C<0> is returned if there is only 1 item.

=item $arr->add_item($item)

=item $arr->add_item($idx => $item)

Add an item to the list of values to check. If index is omitted then the next
index after the last is used.

=item $arr->add_filter(sub { ... })

Add a filter sub. The filter recieves all remaining values of the array being
checked, and should return the values that should still be checked. The filter
will be run between the last item added and the next item added.

=item @deltas = $arr->deltas(got => $got, convert => \&convert, seen => \%seen)

Find the differences between the expected array values and those in the C<$got>
arrayref.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
