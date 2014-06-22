package Test::Builder::Provider;
use strict;
use warnings;

use Test::Builder;
use Carp qw/croak/;
use Scalar::Util qw/blessed reftype set_prototype/;
use B();

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

    my $meta = {};
    my %subs;

    $subs{TB_PROVIDER_META} = sub { $meta };

    # to help transition legacy
    my $builder = sub {
        my $call = Test::Builder->trace_anointed($class);

        return $call->[0]->TB_INSTANCE
            if $call && @$call && $call->[0]->can('TB_INSTANCE');

        return Test::Builder->new;
    };

    $subs{builder} = $builder;
    $subs{TB}      = $builder;

    $subs{anoint} = sub { Test::Builder->anoint($_[1], $_[0]) };

    $subs{untracably_provides} = sub {
        for my $provide (@_) {
            $subs{provide}->($provide, undef, hidden => 1);
        }
    };
    $subs{untracably_provide} = sub {
        $subs{provide}->($_[0], $_[1], hidden => 1);
    };

    $subs{provides} = sub { $subs{provide}->($_) for @_ };
    $subs{provide}  = sub {
        my ($name, $ref, %params) = @_;

        croak "$caller already provides '$name'"
            if $meta->{$name};

        croak "The second argument to provide() must be a ref, got: $ref"
            if $ref && !ref $ref;

        $ref ||= $caller->can($name);
        croak "$caller has no sub named '$name', and no ref was given"
            unless $ref;

        return $meta->{$name} = $ref unless reftype $ref eq 'CODE';

        bless $ref, $class;

        my $o_name = B::svref_2object($ref)->GV->NAME;
        if ($o_name && $o_name ne '__ANON__' && !$params{hidden}) { #sub has a name
            $meta->{$name} = $ref;
        }
        else {
            # Voodoo....
            # Insert an anonymous sub, and use a trick to make caller() think its
            # name is this string, which tells us how to find the thing that was
            # actually called.
            my $key = $params{hidden} ? '__HIDE__' : $name;
            my $subname = __PACKAGE__ . "::__ANON__|$caller\->TB_PROVIDER_META->{$key}";

            my $code = sub {
                no warnings 'once';
                local *__ANON__ = $subname; # Name the sub so we can find it for real.
                $ref->(@_);
            };

            # The prototype on set_prototype blocks this usage, even though it
            # is valid. This is why we use the old-school &func() call.
            # Oh the irony.
            my $proto = prototype($ref);
            &set_prototype($code, $proto) if $proto;

            $meta->{$name} = bless $code, $class;
        }
    };

    $subs{import} = sub {
        my $class = shift;
        my $caller = caller;

        $class->anoint($caller);

        $class->before_import(\@_) if $class->can('before_import');
        my (%no, @list);
        for my $thing (@_) {
            if ($thing =~ m/^!(.*)$/) {
                $no{$1}++;
            }
            else {
                push @list => $thing;
            }
        }

        @list = grep { !$no{$_} } keys %$meta unless @list;
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
