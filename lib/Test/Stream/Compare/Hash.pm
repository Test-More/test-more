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
        if ($self->{+ORDER}) {
            my @all = keys %{$self->{+ITEMS}};
            my %have = map { $_ => 1 } @{$self->{+ORDER}};
            my @missing = grep { !$have{$_} } @all;
            croak "Keys are missing from the 'order' array: " . join(', ', sort @missing)
                if @missing;
        }
        else {
            $self->{+ORDER} = [sort keys %{$self->{+ITEMS}}];
        }
    }

    $self->SUPER::init();
}

sub name { '<HASH>' }

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;
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
    my %params = @_;
    my ($got, $convert, $seen) = @params{qw/got convert seen/};

    my @deltas;
    my $items = $self->{+ITEMS};

    # Make a copy that we can munge as needed.
    my %fields = %$got;

    for my $key (@{$self->{+ORDER}}) {
        my $check  = $convert->($items->{$key});
        my $exists = exists $fields{$key};
        my $val    = delete $fields{$key};

        push @deltas => $check->run(
            id      => [HASH => $key],
            convert => $convert,
            seen    => $seen,
            exists  => $exists,
            $exists ? (got => $val) : (),
        );
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Hash - Representation of a hash in a deep comparison.

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

In deep comparisons this class is used to represent a hash.

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
