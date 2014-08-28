package Test::Builder::HashBase;
use strict;
use warnings;

use Test::Builder::Exporter;
use Carp qw/croak/;

exports qw/accessor accessors/;

export new => sub {
    my ($class, %params) = @_;

    my $self = bless {}, $class;

    while( my ($k, $v) = each(%params) ) {
        croak "$class has no method named '$k'" unless $self->can("set_$k");
        $self->{$k} = $v;
    }

    $self->init(%params) if $self->can('init');

    return $self;
};

Test::Builder::Exporter->cleanup;

sub accessor {
    my ($name, $default) = @_;
    my $caller = caller;

    _accessor($caller, $name, $default);
}

sub accessors {
    my ($name) = @_;
    my $caller = caller;

    _accessor($caller, "$_") for @_;
}

sub _accessor {
    my ($caller, $attr, $default) = @_;
    my $gname = lc $attr;
    my $sname = "set_$gname";
    my $cname = "clear_$gname";

    my $get;
    my $clr = sub { delete $_[0]->{$attr} };
    my $set = sub { $_[0]->{$attr} = $_[1]; };

    if (defined $default) {
        if (ref $default && ref $default eq 'CODE') {
            $get = sub {
                $_[0]->{$attr} = $_[0]->$default unless exists $_[0]->{$attr};
                $_[0]->{$attr};
            };
        }
        elsif ($default eq 'ARRAYREF') {
            $get = sub {
                $_[0]->{$attr} = [] unless exists $_[0]->{$attr};
                $_[0]->{$attr};
            };
        }
        elsif ($default eq 'HASHREF') {
            $get = sub {
                $_[0]->{$attr} = {} unless exists $_[0]->{$attr};
                $_[0]->{$attr};
            };
        }
        else {
            $get = sub {
                $_[0]->{$attr} = $_[1] unless exists $_[0]->{$attr};
                $_[0]->{$attr};
            };
        }
    }
    else {
        $get = sub { $_[0]->{$attr} };
    }

    no strict 'refs';
    *{"$caller\::$gname"} = $get;
    *{"$caller\::$sname"} = $set;
    *{"$caller\::$cname"} = $clr;
}

1;
