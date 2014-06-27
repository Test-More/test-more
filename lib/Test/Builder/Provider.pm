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

my $id = 1;
sub import {
    my $class = shift;
    my @sym_list = @_;
    my $caller = caller;
    my $root = $caller;

    my $meta = {refs => {}, attrs => {}};
    my %subs;

    $subs{TB_PROVIDER_META} = sub { $meta };

    # to help transition legacy
    my $builder = sub {
        my $trace = Test::Builder->trace_test;

        if ($trace && $trace->{report}) {
            my $pkg = $trace->{package};
            return $pkg->TB_INSTANCE
                if $pkg && $pkg->can('TB_INSTANCE');
        }

        return Test::Builder->new;
    };

    $subs{builder} = $builder;
    $subs{TB}      = $builder;

    $subs{anoint} = sub { Test::Builder->anoint($_[1], $_[0]) };

    $subs{provide_nests} = sub {
        for my $provide (@_) {
            $subs{provide}->($provide, undef, nest => 1);
        }
    };
    $subs{provide_nest} = sub {
        $subs{provide}->($_[0], $_[1], nest => 1);
    };

    $subs{gives}    = sub { $subs{provide}->($_, undef, give => 1) for @_ };
    $subs{give}     = sub { $subs{provide}->(@_, give => 1 ) };
    $subs{provides} = sub { $subs{provide}->($_) for @_ };
    $subs{provide}  = sub {
        my ($name, $ref, %params) = @_;

        croak "$caller already provides or gives '$name'"
            if $meta->{attrs}->{$name};

        croak "The second argument to provide() must be a ref, got: $ref"
            if $ref && !ref $ref;

        $ref ||= $caller->can($name);
        croak "$caller has no sub named '$name', and no ref was given"
            unless $ref;

        my $attrs = {%params, package => $caller, name => $name};
        $meta->{attrs}->{$name} = $attrs;

        # If this is just giving, or not a coderef
        return $meta->{refs}->{$name} = $ref if $params{give} || reftype $ref ne 'CODE';

        bless $ref, $class;

        my $o_name = B::svref_2object($ref)->GV->NAME;
        if ($o_name && $o_name ne '__ANON__') { #sub has a name
            $meta->{refs}->{$name} = $ref;
        }
        else {
            # Voodoo....
            # Insert an anonymous sub, and use a trick to make caller() think its
            # name is this string, which tells us how to find the thing that was
            # actually called.
            my $globname = __PACKAGE__ . '::__ANON' . ($id++) . '__';

            my $code = sub {
                no warnings 'once';
                local *__ANON__ = $globname; # Name the sub so we can find it for real.
                $ref->(@_);
            };

            # The prototype on set_prototype blocks this usage, even though it
            # is valid. This is why we use the old-school &func() call.
            # Oh the irony.
            my $proto = prototype($ref);
            &set_prototype($code, $proto) if $proto;

            $meta->{refs}->{$name} = bless $code, $class;

            no strict 'refs';
            *$globname = $code;
            *$globname = $attrs;
        }
    };

    $subs{export} = sub {
        my $class = shift;
        my ($caller, @args) = @_;

        my (%no, @list);
        for my $thing (@args) {
            if ($thing =~ m/^!(.*)$/) {
                $no{$1}++;
            }
            else {
                push @list => $thing;
            }
        }

        my (%export, %export_ok);
        {
            no strict 'refs';
            %export    = map {($_ => 1)} @{"$class\::EXPORT"};
            %export_ok = map {($_ => 1)} @{"$class\::EXPORT_OK"}, @{"$class\::EXPORT"};
        }
        warn "package '$class' uses \@EXPORT and/or \@EXPORT_OK, this is deprecated since '$root' is no longer a subclass of 'Exporter'\n"
            if keys %export_ok;

        unless(@list) {
            my %seen;
            @list = grep { !($no{$_} || $seen{$_}++) } keys(%{$meta->{refs}}), keys(%export);
        }
        for my $name (@list) {
            if ($name =~ m/^(\$|\@|\%)(.*)$/) {
                my ($sig, $sym) = ($1, $2);

                croak "$class does not export '$name'"
                    unless ($meta->{refs}->{$sym} && reftype $meta->{refs}->{$sym} eq $SIG_MAP{$sig})
                        || ($export_ok{$name});

                no strict 'refs';
                *{"$caller\::$sym"} = $meta->{refs}->{$name} || *{"$class\::$sym"}{$sig}
                    || croak "'$class' has no symbol named '$name'";
            }
            else {
                croak "$class does not export '$name'"
                    unless $meta->{refs}->{$name} || $export_ok{$name};

                no strict 'refs';
                *{"$caller\::$name"} = $meta->{refs}->{$name} || $class->can($name)
                    || croak "'$class' has no sub named '$name'";
            }
        }
    };

    $subs{import} = sub {
        my $class = shift;
        my $caller = caller;

        $class->anoint($caller);

        $class->before_import(\@_) if $class->can('before_import');

        $class->export($caller, @_);

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
