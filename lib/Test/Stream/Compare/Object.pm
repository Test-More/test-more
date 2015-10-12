package Test::Stream::Compare::Object;
use strict;
use warnings;

use Test::Stream::Util qw/try/;

use Test::Stream::Compare;
use Test::Stream::Compare::Meta;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/calls meta refcheck ending/],
);

use Carp qw/croak confess/;
use Scalar::Util qw/reftype blessed/;

sub init {
    my $self = shift;
    $self->{+CALLS} ||= [];
    $self->SUPER::init();
}

sub name { '<OBJECT>' }

sub meta_class  { 'Test::Stream::Compare::Meta' }
sub object_base { 'UNIVERSAL' }

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;
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
    my %params = @_;
    my ($got, $convert, $seen) = @params{qw/got convert seen/};

    my @deltas;
    my $meta     = $self->{+META};
    my $refcheck = $self->{+REFCHECK};

    push @deltas => $meta->deltas(%params) if $meta;

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
        else {
            push @deltas => $check->run(
                id      => [METHOD => $name],
                convert => $convert,
                seen    => $seen,
                exists  => $exists,
                $exists ? (got => $val) : (),
            );
        }
    }

    return @deltas unless $refcheck;

    $refcheck->set_ending($self->{+ENDING});

    if ($refcheck->verify(%params)) {
        push @deltas => $refcheck->deltas(%params);
    }
    else {
        push @deltas => $self->delta_class->new(
            verified => undef,
            id       => [META => 'Object Ref'],
            got      => $got,
            check    => $refcheck,
        );
    }

    return @deltas;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Object - Representation of an object during deep
comparison.

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

This class lets you specify an expected object in a deep comparison. You can
check the fields/elements of the underlying reference, call methods to verify
results, and do meta checks for object type and ref type.

=head1 METHODS

=over 4

=item $class = $obj->meta_class

The meta-class to be used when checking the object type. This is mainly listed
because it is useful to override for specialized object subclasses.

This normally just returns L<Test::Stream::Compare::Meta>.

=item $class = $obj->object_base

The base-class to be expected when checking the object type. This is mainly
listed because it is useful to override for specialized object subclasses.

This normally just returns 'UNIVERSAL'.

=item $obj->add_prop(...)

Add a meta-propery to check, see L<Test::Stream::Compare::Meta>. This method
just delegates.

=item $obj->add_field(...)

Add a hash-field to check, see L<Test::Stream::Compare::Hash>. This method
just delegates.

=item $obj->add_item(...)

Add an array item to check, see L<Test::Stream::Compare::Array>. This method
just delegates.

=item $obj->add_call($method, $check)

=item $obj->add_call($method, $check, $name)

Add a method call check. This will call the specified method on your object and
verify the result. C<$method> may be a method name, or a coderef. In the case
of a coderef it can be helpful to provide an alternate name. When no name is
provided the name is either C<$method> or the string '\&CODE'.

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
