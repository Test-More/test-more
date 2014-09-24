package Test::Stream::ArrayBase;
use strict;
use warnings;

use Test::Stream::ArrayBase::Meta;
use Test::Stream::Carp qw/confess croak/;
use Scalar::Util qw/blessed/;

use Test::Stream::Exporter();

sub import {
    my $class = shift;
    my $caller = caller;

    $class->apply_to($caller, @_);
}

sub apply_to {
    my $class = shift;
    my ($caller, %args) = @_;

    # Make the calling class an exporter.
    my $exp_meta = Test::Stream::Exporter::Meta->new($caller);
    Test::Stream::Exporter->export_to($caller, 'import')
        unless $args{no_import};

    my $ab_meta = Test::Stream::ArrayBase::Meta->new($caller);

    my $ISA = do { no strict 'refs'; \@{"$caller\::ISA"} };

    if ($args{base}) {
        my ($base) = grep { $_->isa($class) } @$ISA;

        croak "$caller is already a subclass of '$base', cannot subclass $args{base}"
            if $base;

        my $file = $args{base};
        $file =~ s{::}{/}g;
        $file .= ".pm";
        require $file unless $INC{$file};

        my $pmeta = Test::Stream::ArrayBase::Meta->get($args{base});
        croak "Base class '$args{base}' is not a subclass of $class!"
            unless $pmeta;

        push @$ISA => $args{base};

        $ab_meta->subclass($args{base});
    }
    elsif( !grep { $_->isa($class) } @$ISA) {
        push @$ISA => $class;
        $ab_meta->baseclass();
    }

    if ($args{accessors}) {
        $ab_meta->add_accessor($_) for @{$args{accessors}};
    }

    1;
}

sub new {
    my $class = shift;
    my $self = bless [@_], $class;
    $self->init if $self->can('init');
    return $self;
}

sub new_from_pairs {
    my $class = shift;
    my %params = @_;
    my $self = bless [], $class;

    while (my ($k, $v) = each %params) {
        my $const = uc($k);
        croak "$class has no accessor named '$k'" unless $class->can($const);
        my $id = $class->$const;
        $self->[$id] = $v;
    }

    $self->init if $self->can('init');
    return $self;
}

sub to_hash {
    my $array_obj = shift;
    my $meta = Test::Stream::ArrayBase::Meta->get(blessed $array_obj);
    my $fields = $meta->fields;
    my %out;
    for my $f (keys %$fields) {
        my $i = $fields->{$f};
        my $val = $array_obj->[$i];
        my $ao = blessed($val) && $val->isa(__PACKAGE__);
        $out{$f} = $ao ? $val->to_hash : $val;
    }
    return \%out;
};

1;

