package Test::Stream::Exporter::Meta;
use strict;
use warnings;

my %EXPORT_META;

# Test::Stream::Carp uses this module.
sub croak   { require Carp; goto &Carp::croak }
sub confess { require Carp; goto &Carp::confess }

sub EXPORTS() { 'exports' }
sub PACKAGE() { 'package' }
sub DEFAULT() { 'default' }

sub exports { $_[0]->{+EXPORTS} }
sub default { $_[0]->{+DEFAULT} }

sub get { $EXPORT_META{$_[-1]} }

sub new {
    my ($class, $pkg) = @_;

    confess "Package is required!"
        unless $pkg;

    my $meta = $EXPORT_META{$pkg};
    return $meta if $meta;

    $meta = bless({
        EXPORTS() => {},
        DEFAULT() => [],
        PACKAGE() => $pkg,
    }, $class);

    return $EXPORT_META{$pkg} = $meta;
}

sub add {
    my ($self, $default, $name, $ref) = @_;

    confess "Name is mandatory" unless $name;

    confess "$name is already exported"
        if $self->{+EXPORTS}->{$name};

    my $pkg = $self->{+PACKAGE};

    unless ($ref) {
        no strict 'refs';
        $ref = *{"$pkg\::$name"}{CODE};
    }

    confess "No reference or package sub found for '$name' in '$pkg'"
        unless $ref && ref $ref;

    # Add the export ref
    $self->{+EXPORTS}->{$name} = $ref;
    push @{$self->{+DEFAULT}} => $name if $default;
}

sub add_bulk {
    my $self    = shift;
    my $default = shift;

    my $pkg = $self->{+PACKAGE};

    for my $name (@_) {
        confess "$name is already exported"
            if $self->{+EXPORTS}->{$name};

        no strict 'refs';
        $self->{+EXPORTS}->{$name} = *{"$pkg\::$name"}{CODE}
            || confess "No reference or package sub found for '$name' in '$pkg'";
    }

    push @{$self->{+DEFAULT}} => @_ if $default;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Exporter::Meta - Meta object for exporters.

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

L<Test::Stream::Exporter> uses this package to manage exports.

Every package that uses C<Test::Stream::Exporter> has a
C<Test::Stream::Exporter::Meta> object created for it which contains the
metadata about the available exports and the kind of export they are.

=head1 FUNCTIONS

=over 4

=item $meta = Test::Stream::Exporter::Meta::get( $PACKAGE )

Returns a C<metaobject> for C<$PACKAGE> if one exists. Returns C<undef> if one
does not exist. This can be used as either a method or a function, the last
argument is the only one that is used.

=back

=head1 METHODS

=over 4

=item $meta = Test::Stream::Exporter::Meta->new( $PACKAGE )

Constructs a C<metaobject> for C<$PACKAGE> and returns it. If one already
exists, it is returned.

=item metaobject->add( $DEFAULT, $SUBNAME )

=item metaobject->add( $DEFAULT, $SUBNAME => $SUBREF )

Add an export named C<$SUBNAME>. If a ref is provided it will be used,
otherwise it will grab the sub from the package using C<$SUBNAME>. The fist
argument is a toggle, true means the sub is exported by default, false means it
is not exported by default.

=item metaobject->add_bulk( $DEFAULT, $SUBNAME, $SUBNAME, ... )

Add all the subnames given as arguments to the list of exports. The subs of the
given names are taken as the references. The first argument is a toggle, true
means the susb should be exported by default, false means they should not be.

=item $default_ref = metaobject->default()

Get the arrayref of default exports. This is not a copy of the arrayref,
modifying this would modify the internal list of defaults.

=item $exports_ref = metaobject->exports()

Returns a C<HASHREF> of C<< $SUBNAME => $CODEREF >> values of all avialable
exports.

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

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
