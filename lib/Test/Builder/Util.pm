package Test::Builder::Util;
use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/reftype blessed/;
use Test::Builder::Threads;

my $meta = {};
sub TB_EXPORT_META { $meta };

exports(qw/
    import export exports accessor accessors delta deltas export_to transform
    atomic_delta atomic_deltas
/);

export(new => sub {
    my $class = shift;
    my %params = @_;

    my $self = bless {}, $class;

    for my $attr (keys %params) {
        croak "$class has no method named '$attr'" unless $self->can($attr);
        $self->$attr($params{$attr});
    }

    $self->init(%params) if $self->can('init');

    return $self;
});

sub import {
    my $class = shift;
    my $caller = caller;

    if (grep {$_ eq 'import'} @_) {
        my $meta = {};
        no strict 'refs';
        *{"$caller\::TB_EXPORT_META"} = sub { $meta };
    }

    $class->export_to($caller, @_) if @_;

    1;
}

sub export_to {
    my $from = shift;
    my ($to, @subs) = @_;

    croak "package '$from' is not a TB exporter"
        unless $from->can('TB_EXPORT_META');

    croak "No destination package specified."
        unless $to;

    return unless @subs;

    my $meta = $from->TB_EXPORT_META;

    for my $name (@subs) {
        my $ref = $meta->{$name} || croak "$from does not export '$name'";
        no strict 'refs';
        *{"$to\::$name"} = $ref;
    }

    1;
}

sub exports {
    my $caller = caller;

    croak "$caller is not an exporter!"
        unless $caller->can('TB_EXPORT_META');

    my $meta = $caller->TB_EXPORT_META;

    for my $name (@_) {
        my $ref = $caller->can($name);
        croak "$caller has no sub named '$name'" unless $ref;

        croak "Already exporting '$name'"
            if $meta->{$name};

        $meta->{$name} = $ref;
    }
}

sub export {
    my ($name, $ref) = @_;
    my $caller = caller;

    croak "The first argument to export() must be a symbol name"
        unless $name;

    $ref ||= $caller->can($name);
    croak "$caller has no sub named '$name', and no ref was provided"
        unless $ref;

    # Allow any type of ref, people can export scalars, hashes, etc.
    croak "The second argument to export() must be a reference"
        unless ref $ref;

    croak "$caller is not an exporter!"
        unless $caller->can('TB_EXPORT_META');

    my $meta = $caller->TB_EXPORT_META;

    croak "Already exporting '$name'"
        if $meta->{$name};

    $meta->{$name} = $ref;
}

sub accessor {
    my ($name, $default) = @_;
    my $caller = caller;

    croak "The second argument to accessor() must be a coderef, not '$default'"
        if $default && !(ref $default && reftype $default eq 'CODE');

    _accessor($caller, $name, $default);
}

sub accessors {
    my ($name) = @_;
    my $caller = caller;

    _accessor($caller, "$_") for @_;
}

sub _accessor {
    my ($caller, $attr, $default) = @_;
    my $name = lc $attr;

    my $sub = sub {
        my $self = shift;
        croak "$name\() must be called on a blessed instance, got: $self"
            unless blessed $self;

        $self->{$attr} = $self->$default if $default && !exists $self->{$attr};
        ($self->{$attr}) = @_ if @_;

        return $self->{$attr};
    };

    no strict 'refs';
    *{"$caller\::$name"} = $sub;
}

sub transform {
    my $name = shift;
    my $code = pop;
    my ($attr) = @_;
    my $caller = caller;

    $attr ||= $name;

    croak "name is mandatory"              unless $name;
    croak "takes a minimum of 2 arguments" unless $code;

    my $sub = sub {
        my $self = shift;
        croak "$name\() must be called on a blessed instance, got: $self"
            unless blessed $self;

        $self->{$attr} = $self->$code(@_) if @_ and defined $_[0];

        return $self->{$attr};
    };

    no strict 'refs';
    *{"$caller\::$name"} = $sub;
}

sub delta {
    my ($name, $initial) = @_;
    my $caller = caller;

    _delta($caller, $name, $initial || 0, 0);
}

sub deltas {
    my $caller = caller;
    _delta($caller, "$_", 0, 0) for @_;
}

sub atomic_delta {
    my ($name, $initial) = @_;
    my $caller = caller;

    _delta($caller, $name, $initial || 0, 1);
}

sub atomic_deltas {
    my $caller = caller;
    _delta($caller, "$_", 0, 1) for @_;
}

sub _delta {
    my ($caller, $attr, $initial, $atomic) = @_;
    my $name = lc $attr;

    my $sub = sub {
        my $self = shift;

        croak "$name\() must be called on a blessed instance, got: $self"
            unless blessed $self;

        lock $self->{$attr} if $atomic;
        $self->{$attr} = $initial unless exists $self->{$attr};
        $self->{$attr} += $_[0] if @_;

        return $self->{$attr};
    };

    no strict 'refs';
    *{"$caller\::$name"} = $sub;
}

1;
