package Test::Stream::Exporter::Meta;
use strict;
use warnings;

use Test::Stream::PackageUtil;

# Test::Stream::Carp uses this module.
sub croak   { require Carp; goto &Carp::croak }
sub confess { require Carp; goto &Carp::confess }

sub exports { $_[0]->{exports} }
sub default { keys %{$_[0]->{default}} }
sub all     { keys %{$_[0]->{exports}} }

sub add {
    my $self = shift;
    my ($name, $ref) = @_;

    confess "Name is mandatory" unless $name;

    confess "$name is already exported"
        if $self->exports->{$name};

    $ref ||= package_sym($self->{package}, CODE => $name);

    confess "No reference or package sub found for '$name' in '$self->{package}'"
        unless $ref && ref $ref;

    $self->exports->{$name} = $ref;
}

sub add_default {
    my $self = shift;
    my ($name, $ref) = @_;

    $self->add($name, $ref);

    $self->{default}->{$name} = 1;
}

my %EXPORT_META;

sub new {
    my $class = shift;
    my ($pkg) = @_;

    confess "Package is required!"
        unless $pkg;

    $EXPORT_META{$pkg} ||= bless({
        exports => {},
        default => {},
        package => $pkg,
    }, $class);

    return $EXPORT_META{$pkg};
}

sub get {
    my $class = shift;
    my ($pkg) = @_;

    confess "Package is required!"
        unless $pkg;

    return $EXPORT_META{$pkg};
}

1;
