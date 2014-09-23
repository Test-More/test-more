package Test::Stream::ArrayBase::Meta;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;

my %META;

sub package {     shift->{package}   }
sub parent  {     shift->{parent}    }
sub locked  {     shift->{locked}    }
sub fields  {({ %{shift->{fields}} })}

sub new {
    my $class = shift;
    my ($pkg) = @_;

    $META{$pkg} ||= bless {
        package => $pkg,
        locked  => 0,
    }, $class;

    return $META{$pkg};
}

sub get {
    my $class = shift;
    my ($pkg) = @_;

    return $META{$pkg};
}

sub baseclass {
    my $self = shift;
    $self->{parent} = 'Test::Stream::ArrayBase';
    $self->{index}  = 0;
    $self->{fields} = {};
}

sub subclass {
    my $self = shift;
    my ($parent) = @_;
    confess "Already a subclass of $self->{parent}! Tried to sublcass $parent" if $self->{parent};

    my $pmeta = $self->get($parent) || die "$parent is not an ArrayBase object!";
    $pmeta->{locked} = 1;

    $self->{parent} = $parent;
    $self->{index}  = $pmeta->{index};
    $self->{fields} = $pmeta->fields; #Makes a copy

    my $ex_meta = Test::Stream::Exporter::Meta->get($self->{package});

    # Put parent constants into the subclass
    for my $field (keys %{$self->{fields}}) {
        my $const = uc $field;
        no strict 'refs';
        *{"$self->{package}\::$const"} = $parent->can($const) || confess "Could not find constant '$const'!";
        $ex_meta->add($const);
    }
}

sub add_accessor {
    my $self = shift;
    my ($name) = @_;

    confess "Cannot add accessor, metadata is locked due to a subclass being initialized."
        if $self->{locked};

    confess "field '$name' already defined!"
        if exists $self->{fields}->{$name};

    my $idx = $self->{index}++;
    $self->{fields}->{$name} = $idx;

    my $const = uc $name;
    my $gname = lc $name;
    my $sname = "set_$gname";
    my $cname = "clear_$gname";

    eval qq|
        package $self->{package};
        sub $gname { \$_[0]->[$idx] }
        sub $sname { \$_[0]->[$idx] = \$_[1] }
        sub $cname { \$_[0]->[$idx] = undef  }
        sub $const() { $idx }
        1
    | || confess $@;

    # Add the constant as an optional export
    my $ex_meta = Test::Stream::Exporter::Meta->get($self->{package});
    $ex_meta->add($const);
}

1;
