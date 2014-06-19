package Test::Builder::Provider;
use strict;
use warnings;

use Test::Builder;
use Carp qw/croak/;
use Scalar::Util qw/blessed reftype/;

sub import {
    my $class = shift;
    my @sub_list = @_;
    my $caller = caller;

    my $tb = Test::Builder->create(
        modern        => 1,
        shared_stream => 1,
    );

    $tb->anoint(provider => $caller);

    my $meta = {};
    my %subs;

    $subs{TB_META} = sub { $meta };
    $subs{TB}      = sub { $tb   };

    $subs{provide} = sub {
        my ($name, $code) = @_;

        croak "$caller already provides '$name'"
            if $meta->{$name};

        croak "The second argument to provide() must be a coderef"
            if $code && !(reftype($code) && reftype($code) eq 'CODE');

        $code ||= $caller->can($name);
        croak "$caller has no sub named '$name', and no subref was given"
            unless $code;

        bless $code, $class;
        $meta->{$name} = $code;
    };

    $subs{import} = sub {
        my $self = shift;
        my @list = @_;
        my $caller = caller;

        $tb->anoint(tester => $caller);

        @list = keys %$meta unless @list;
        for my $name (@list) {
            no strict 'refs';
            *{"$caller\::$name"} = $subs{$name};
        }

        1;
    };

    @sub_list = keys %subs unless @sub_list;
    for my $name (@sub_list) {
        no strict 'refs';
        *{"$caller\::$name"} = $subs{$name};
    }

    1;
}

1;
