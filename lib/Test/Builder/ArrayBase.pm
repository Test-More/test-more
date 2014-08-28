package Test::Builder::ArrayBase;
use strict;
use warnings;

use Test::Builder::Exporter;
use Carp qw/confess/;

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
    if ($importer->can('AB_IDX')) {
        $IDX = $importer->AB_IDX;
        my $parent = $importer->AB_CLASS;
        no strict 'refs';
        no warnings 'redefine';
        *{"$parent\::AB_NEW_IDX"} = $LOCKED;
    }

    no strict 'refs';
    *{"$importer\::AB_IDX"}     = sub { $IDX };
    *{"$importer\::AB_NEW_IDX"} = sub { $IDX++ };
    *{"$importer\::AB_CLASS"}   = sub { $importer };
}

exports qw/accessor accessors/;

export new => sub {
    my $class = shift;
    my $self = bless [@_], $class;
    $self->init if $self->can('init');
    return $self;
};

Test::Builder::Exporter->cleanup;

sub accessor {
    my($name, $default) = @_;
    my $caller = caller;
    _accessor($caller, $name, $default);
}

sub accessors {
    my $caller = caller;
    _accessor($caller, $_) for @_;
}

sub _accessor {
    my ($caller, $name, $default) = @_;

    my $idx = $caller->AB_NEW_IDX;

    my $const = uc $name;
    my $gname = lc $name;
    my $sname = "set_$gname";
    my $cname = "clear_$gname";

    my $get;
    my $clr = sub { $_[0]->[$idx] = undef };
    my $set = sub { $_[0]->[$idx] = $_[1] };

    if (defined $default) {
        if (ref $default && ref $default eq 'CODE') {
            $get = sub {
                $_[0]->[$idx] = $_[0]->$default unless exists $_[0]->[$idx];
                $_[0]->[$idx];
            };
        }
        elsif ($default eq 'ARRAYREF') {
            $get = sub {
                $_[0]->[$idx] = [] unless exists $_[0]->[$idx];
                $_[0]->[$idx];
            };
        }
        elsif ($default eq 'HASHREF') {
            $get = sub {
                $_[0]->[$idx] = {} unless exists $_[0]->[$idx];
                $_[0]->[$idx];
            };
        }
        else {
            $get = sub {
                $_[0]->[$idx] = $_[1] unless exists $_[0]->[$idx];
                $_[0]->[$idx];
            };
        }
    }
    else {
        $get = sub { $_[0]->[$idx] };
    }

    no strict 'refs';
    *{"$caller\::$gname"} = $get;
    *{"$caller\::$sname"} = $set;
    *{"$caller\::$cname"} = $clr;
    *{"$caller\::$const"} = sub() { $idx };
}

1;

