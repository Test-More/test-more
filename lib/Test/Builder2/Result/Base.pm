package Test::Builder2::Result::Base;

use Test::Builder2::Mouse;

my $CLASS = __PACKAGE__;

my %attributes = (
  description   => { },
  diagnostic    => { isa => 'ArrayRef', },
  id            => { },
  location      => { },
  reason        => { },
  test_number   => { isa => 'Test::Builder2::Positive_Int', },
);
my @attributes = keys %attributes;

my %attr_defaults = (
    is  => 'rw',
    isa => 'Str',
);

for my $attr (keys %attributes) {
    my $has = $attributes{$attr};
    $has = { %attr_defaults, %$has };

    $has->{predicate} ||= "has_$attr";
    has $attr => %$has;
}

_alias($CLASS, name => \&description);
_alias($CLASS, diag => \&diagnostic);
_alias($CLASS, file => \&location);
_alias($CLASS, line => \&id);


sub get_attributes
{
    return \@attributes;
}


sub as_hash {
    my $self = shift;
    return {
        map {
            my $val = $self->$_();
            defined $val ? ( $_ => $val ) : ()
        } @attributes, "type"
    };
}


# Throw out any keys which have undef values.
# This makes it easier to construct objects without having to
# first check if the value is defined.
override BUILDARGS => sub {
    my $args = super;
    for (keys %$args) {
        delete $args->{$_} unless defined $args->{$_};
    }

    return $args;
};


use overload(
    q{bool} => sub {
        my $self = shift;
        return !$self->is_fail;
    },
    fallback => 1,
);

sub literal_pass {
    return 0;
}

sub is_unknown {
    return 0;
}

sub is_pass {
    my $self = shift;
    return $self->literal_pass;
}

sub is_fail {
    my $self = shift;
    return !$self->literal_pass;
}

sub is_todo {
    return 0;
}

sub is_skip {
    return 0;
}

my %TypeMap = (
    pass        => "is_pass",
    fail        => "is_fail",
    todo        => "is_todo",
    skip        => "is_skip",
    unknown     => "is_unknown",
);
sub types {
    my $self = shift;
    my %types;
    for my $type (sort { $a cmp $b } keys %TypeMap) {
        my $method = $TypeMap{$type};
        $types{$type} = $self->$method;
    }

    return \%types;
}

sub _alias {
    my($class, $name, $code) = @_;

    no strict 'refs';
    *{$class . "::" . $name} = $code;
}


1;
