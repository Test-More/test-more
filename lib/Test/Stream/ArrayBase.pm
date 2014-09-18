package Test::Stream::ArrayBase;
use strict;
use warnings;

use Test::Stream::Exporter;
use Test::Stream::Carp qw/confess croak/;
use Scalar::Util();

my $LOCKED = sub {
    confess <<"    EOT";
Attempt to add a new accessor to $_[0]!
Index is already locked due to a subclass being initialized.
    EOT
};

sub after_import {
    my ($class, $importer, $stash, @args) = @_;

    # If we are a subclass of another ArrayBase class we will start our indexes
    # after the others.
    my $IDX = 0;
    my $fields;

    if ($importer->can('AB_IDX')) {
        $IDX = $importer->AB_IDX;
        $fields = [@{$importer->AB_FIELDS}];

        my $parent = $importer->AB_CLASS;
        no strict 'refs';
        no warnings 'redefine';
        *{"$parent\::AB_NEW_IDX"} = $LOCKED;

        for(my $i = 0; $i < @$fields; $i++) {
            *{$importer . '::' . uc($fields->[$i])} = sub() { $i };
        }
    }
    else {
        $fields = [];
    }

    no strict 'refs';
    *{"$importer\::AB_IDX"}     = sub { $IDX };
    *{"$importer\::AB_NEW_IDX"} = sub { $IDX++ };
    *{"$importer\::AB_CLASS"}   = sub { $importer };
    *{"$importer\::AB_FIELDS"}  = sub { $fields };
}

exports qw/accessor accessors to_hash new new_from_pairs/;
unexports qw/accessor accessors/;

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
    my $fields = $array_obj->AB_FIELDS;
    my %out;
    for(my $i = 0; $i < @$fields; $i++) {
        my $inner = $array_obj->[$i];
        my $ao = Scalar::Util::blessed($inner) && $inner->isa(__PACKAGE__);
        $out{$fields->[$i]} = $ao ? $ao->to_hash : $array_obj->[$i];
    }
    return \%out;
};

Test::Stream::Exporter->cleanup;

sub accessor {
    my($name, $default) = @_;
    my $caller = caller;
    my $fields = $caller->AB_FIELDS;
    _accessor($caller, $fields, $name, $default);
}

sub accessors {
    my $caller = caller;
    my $fields = $caller->AB_FIELDS;
    _accessor($caller, $fields, $_) for @_;
}

sub _accessor {
    my ($caller, $fields, $name, $default) = @_;

    my $idx = $caller->AB_NEW_IDX;
    push @$fields => $name;

    my $const = uc $name;
    my $gname = lc $name;
    my $sname = "set_$gname";
    my $cname = "clear_$gname";

    my $get = "";
    if (defined $default) {
        if (ref $default && ref $default eq 'CODE') {
            $get = qq|\$_[0]->[$idx] = \$_[0]->\$default unless exists \$_[0]->[$idx];|;
        }
        elsif ($default eq 'ARRAYREF') {
            $get = qq|\$_[0]->[$idx] = [] unless exists \$_[0]->[$idx];|;
        }
        elsif ($default eq 'HASHREF') {
            $get = qq|\$_[0]->[$idx] = {} unless exists \$_[0]->[$idx];|;
        }
        else {
            $get = qq|\$_[0]->[$idx] = \$_[1] unless exists \$_[0]->[$idx];|;
        }
    }

    eval qq|
        package $caller;
        sub $gname { $get \$_[0]->[$idx] }
        sub $sname { \$_[0]->[$idx] = \$_[1] }
        sub $cname { \$_[0]->[$idx] = undef  }
        sub $const() { $idx }
        1
    | || die $@;
}

1;

