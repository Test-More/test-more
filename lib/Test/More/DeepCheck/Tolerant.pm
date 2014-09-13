package Test::More::DeepCheck::Tolerant;
use strict;
use warnings;

use Test::More::Tools;
use Scalar::Util qw/reftype blessed/;
use Test::Stream::Util qw/try unoverload_str/;

use base 'Test::More::DeepCheck';
use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/stack_start/;
    Test::Stream::ArrayBase->cleanup;
}

sub preface { "First mismatch:\n" };

sub check {
    my $class = shift;
    my ($got, $expect) = @_;

    unoverload_str(\$got, \$expect);
    my $self = $class->new();

    # neither is a reference
    return tmt->is_eq($got, $expect)
        if !ref $got and !ref $expect;

    push @$self => {type => '', vals => [$got, $expect], line => __LINE__};
    my $ok = $self->_deep_check($got, $expect);
    return ($ok, $ok ? () : $self->format_stack);
}

#============================

sub _reftype {
    my ($thing) = @_;
    my $type = reftype $thing || return '';

    $type = uc($type);

    return $type unless $type eq 'SCALAR';

    $type = 'REGEXP' if $thing =~ m/^\(\?\^[a-z]*:.*\)$/ || $type eq 'REGEX';

    return $type;
}

sub _nonref_check {
    my ($self) = shift;
    my ($got, $expect) = @_;

    my $numeric = $got =~ m/^[0-9\._ef]+$/i && $expect =~ m/^[0-9\._ef]+$/i;
    return $numeric ? $got == $expect : "$got" eq "$expect";
}

sub _deep_check {
    my ($self) = shift;
    my ($got, $expect) = @_;

    return 1 unless defined($got) ||  defined($expect);
    return 0 if     defined($got) xor defined($expect);

    my $seen = $self->[SEEN]->[-1];
    return 1 if $seen->{$got} && $seen->{$got} eq $expect;
    $seen->{$got} = "$expect";

    my $etype = _reftype $expect;
    my $gtype = _reftype $got;

    return 0 if ($etype && $etype ne 'REGEXP' && !$gtype) || ($gtype && !$etype);

    return $self->_nonref_check($got, $expect) unless $etype;

    ##### Both are refs at this point ####
    return 1 if $gtype && $got == $expect;

    if ($etype eq 'REGEXP') {
        return "$got" eq "$expect" if $gtype eq 'REGEXP'; # Identical regexp check
        return $got =~ $expect;
    }

    my $ok = 0;
    $seen = {%$seen};
    push @{$self->[SEEN]} => $seen;
    if ($etype eq 'ARRAY') {
        $ok = $self->_array_check($got, $expect);
    }
    elsif ($etype eq 'HASH') {
        $ok = $self->_hash_check($got, $expect);
    }
    pop @{$self->[SEEN]};

    return $ok;
}

sub _array_check {
    my $self = shift;
    my ($got, $expect) = @_;

    return 0 if _reftype($got) ne 'ARRAY';

    for (my $i = 0; $i < @$expect; $i++) {
        push @$self => {type => 'ARRAY', idx => $i, vals => [$got->[$i], $expect->[$i]], line => __LINE__};
        $self->_deep_check($got->[$i], $expect->[$i]) || return 0;
        pop @$self;
    }

    return 1;
}

sub _hash_check {
    my $self = shift;
    my ($got, $expect) = @_;

    my $blessed  = blessed($got);
    my $hashref  = _reftype($got) eq 'HASH';
    my $arrayref = _reftype($got) eq 'ARRAY';

    for my $key (sort keys %$expect) {
        #                                             $wrap   $direct  $field   Leftover from wrap
        my ($wrap, $direct, $field) = ($key =~ m/^  ([\[\{]?)   (:?)   ([^\]]*) [\]\}]?$/x);

        if ($wrap) {
            if (!$blessed) {
                push @$self => {
                    type  => 'OBJECT',
                    idx   => $field,
                    wrap  => $wrap,
                    vals  => ["(EXCEPTION)", $expect->{$key}],
                    error => "Cannot call method '$field' on an unblessed reference.\n",
                    line  => __LINE__,
                };
                return 0;
            }
            if ($direct) {
                push @$self => {
                    type  => 'OBJECT',
                    idx   => $field,
                    wrap  => $wrap,
                    vals  => ['(EXCEPTION)', $expect->{$key}],
                    error => "'$key' is invalid, cannot wrap($wrap) a direct-access($direct).\n",
                    line  => __LINE__,
                };
                return 0;
            }
        }

        my ($val, $type);
        if ($direct || !$blessed) {
            if ($arrayref) {
                $type = 'ARRAY';
                if ($field !~ m/^-?\d+$/i) {
                    push @$self => {
                        type  => 'ARRAY',
                        idx   => $field,
                        vals  => ['(EXCEPTION)', $expect->{$key}],
                        error => "'$field' is not a valid array index\n",
                        line  => __LINE__,
                    };
                    return 0;
                }

                # Try, if they specify -1 in an empty array it may throw an exception
                my ($success, $error) = try { $val = $got->[$field] };
                if (!$success) {
                    push @$self => {
                        type  => 'ARRAY',
                        idx   => $field,
                        vals  => ['(EXCEPTION)', $expect->{$key}],
                        error => $error,
                        line  => __LINE__,
                    };
                    return 0;
                }
            }
            else {
                $type = 'HASH';
                $val  = $got->{$field};
            }
        }
        else {
            $type = 'OBJECT';
            my ($success, $error) = try {
                if ($wrap) {
                    if ($wrap eq '[') {
                        $val = [$got->$field()];
                    }
                    elsif ($wrap eq '{') {
                        $val = {$got->$field()};
                    }
                    else {
                        die "'$wrap' is not a valid way to wrap a method call";
                    }
                }
                else {
                    $val = $got->$field();
                }
            };
            if (!$success) {
                push @$self => {
                    type  => 'OBJECT',
                    idx   => $field,
                    wrap  => $wrap || undef,
                    vals  => ['(EXCEPTION)', $expect->{$key}],
                    error => $error,
                    line  => __LINE__,
                };
                return 0;
            }
        }

        push @$self => {type => $type, idx => $field, vals => [$val, $expect->{$key}], line => __LINE__, wrap => $wrap || undef};
        $self->_deep_check($val, $expect->{$key}) || return 0;
        pop @$self;
    }

    return 1;
}

1;
