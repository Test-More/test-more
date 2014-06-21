package Test::Builder::Provider;
use strict;
use warnings;

use Test::Builder;
use Carp qw/croak/;
use Scalar::Util qw/blessed reftype/;

my %SIG_MAP = (
    '$' => 'SCALAR',
    '@' => 'ARRAY',
    '%' => 'HASH',
    '&' => 'CODE',
);

sub import {
    my $class = shift;
    my @sym_list = @_;
    my $caller = caller;

    my $tb = Test::Builder->create(
        modern        => 1,
        shared_stream => 1,
    );

    my $meta = {};
    my %subs;

    $subs{TB_PROVIDER_META} = sub { $meta };

    # to help transition legacy
    $subs{builder} = sub { $tb };
    $subs{TB}      = sub { $tb };

    $subs{anoint} = sub { $tb->anoint($_[1], $_[0]) };

    $subs{provides} = sub { $subs{provide}->($_) for @_ };
    $subs{provide}  = sub {
        my ($name, $ref) = @_;

        croak "$caller already provides '$name'"
            if $meta->{$name};

        croak "The second argument to provide() must be a ref, got: $ref"
            if $ref && !ref $ref;

        $ref ||= $caller->can($name);
        croak "$caller has no sub named '$name', and no ref was given"
            unless $ref;

        # Voodoo....
        # Insert an anonymous sub, and use a trick to make caller() think its
        # name is this string, which tells us how to find the thing that was
        # actually called.
        my $subname = __PACKAGE__ . "::__ANON__|$caller\->TB_PROVIDER_META->{$name}";
        bless $ref, $class;
        $meta->{$name} = bless sub {
            local *__ANON__ = $subname; # Name the sub so we can find it for real.
            $ref->(@_);
        }, $class;
    };

    $subs{import} = sub {
        my $class = shift;
        my $caller = caller;

        $class->anoint($caller);

        $class->before_import(\@_) if $class->can('before_import');
        my @list = @_;

        @list = keys %$meta unless @list;
        for my $name (@list) {
            if ($name =~ s/^(\$|\@|\%)//) {
                my $sig = $1;

                croak "$class does not export '$sig$name'"
                    unless $meta->{$name}
                        && reftype $meta->{$name} eq $SIG_MAP{$sig};
            }

            croak "$class does not export '$name'"
                unless $meta->{$name};

            no strict 'refs';
            *{"$caller\::$name"} = $meta->{$name};
        }

        $class->after_import(@_) if $class->can('after_import');

        1;
    };

    @sym_list = keys %subs unless @sym_list;

    for my $name (@sym_list) {
        no strict 'refs';
        my $ref = $subs{$name} || $class->can($name);
        croak "$class does not export '$name'" unless $ref;
        *{"$caller\::$name"} = $ref ;
    }

    1;
}

1;
