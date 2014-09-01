package Test::Provider::Tools;
use strict;
use warnings;

use Test::Stream::Exporter;
exports qw/pt/;
Test::Stream::Exporter->cleanup;

use Scalar::Util qw/reftype blessed/;

sub pt() { __PACKAGE__ }

sub mostly_like {
    my ($class, $got, $want) = @_;
    _mostly_like($got, $want);
}

#============================

sub _mostly_like {
    my ($got, $want, $rawname) = @_;
    my $name = $rawname ? "$rawname = " : " = ";
    $rawname ||= "";

    return (1) unless defined($got) || defined($want);

    return (0, "#    GOT$name'$got'\n# WANTED${name}undef\n")
        if defined $got && !defined $want;

    return (0, "#    GOT${name}undef\n# WANTED$name'$want'\n")
        if defined $want && !defined $got;

    # TODO: Regex on old perls
    my $wtype = reftype $want || "";
    my $gtype = reftype $got  || "";

    return (0, "#    GOT$name'$got'\n# WANTED$name'$want'\n")
        if ($wtype && $wtype ne 'REGEXP' && !$gtype)
        || ($gtype && !$wtype);

    unless ($wtype) {
        my $numeric = $got =~ m/^[0-9\._ef]+$/i && $want =~ m/^[0-9\._ef]+$/i;
        my $bool = $numeric ? $got == $want : "$got" eq "$want";

        return ($bool) if $bool;
        return ($bool, "#    GOT$name'$got'\n# WANTED$name'$want'\n");
    }

    return (1) if $gtype && $got == $want;

    if ($wtype eq 'REGEXP') {
        if ($gtype eq 'REGEXP') {
            return (1) if "$got" eq "$want";
            return (0, "#    GOT$name'$got'\n# WANTED$name'$want'\n");
        }

        my $bool = $got =~ $want;
        return ($bool) if $bool;
        return ($bool, "# Regex does not match!\n#    GOT$name$got\n# WANTED$name$want\n");
    }

    return _mostly_like_array($got, $want, $rawname, $name) if $wtype eq 'ARRAY';
    return _mostly_like_hash ($got, $want, $rawname, $name) if $wtype eq 'HASH';
    return (0,  "Not sure what to do with WANT$name'$want'");
}

sub _mostly_like_array {
    my ($got, $want, $rawname, $name) = @_;

    return (0, "#    GOT$name'$got'\n# WANTED$name'$want'\n") if reftype $got ne 'ARRAY';

    my ($ok, @diag) = (1);
    for(my $i = 0; $i < @$want; $i++) {
        my ($v, @msgs) = _mostly_like($got->[$i], $want->[$i], "$rawname\->[$i]");
        $ok &&= $v;
        push @diag => @msgs;
    }

    return ($ok, @diag);
}

sub _mostly_like_hash {
    my ($got, $want, $rawname, $name) = @_;

    my $blessed  = blessed $got;
    my $hashref  = reftype $got eq 'HASH';
    my $arrayref = reftype $got eq 'ARRAY';

    my ($ok, @diag) = (1);
    for my $key (keys %$want) {
        my ($wrap, $direct, $field) = ($key =~ m/^([\[\{]?)(:?)([^\]]*)[\]\}]?$/);
        if ($wrap) {
            if ($direct) {
                $ok = 0;
                push @diag => "Cannot combine 'wrap' and 'direct': '$field' is invalid at CHECK$name\n";
                next;
            }
            if (!$blessed) {
                $ok = 0;
                push @diag => "Cannot use 'wrap' on an unblessed reference: '$field' is invalid at CHECK$name\n";
                next;
            }
        }

        my ($v, @msgs);
        if ($direct || !$blessed) {
            if ($arrayref) {
                if ($field !~ m/^[0-9_\.ef]+$/i) {
                    $ok = 0;
                    push @diag => "# Cannot use a string index into an arrayref\n#    GOT$rawname\->[$field]\n# WANTED$rawname\->{$field}\n";
                    next;
                }

                eval {
                    ($v, @msgs) = _mostly_like($got->[$field], $want->{$key}, "$rawname\->[$field]");
                    1;
                } || do { $v = 0; push @diag => "# EXCEPTION: ${@}#    WANTED$rawname\->[$field]\n" };
            }
            else {
                eval {
                    ($v, @msgs) = _mostly_like($got->{$field}, $want->{$key}, "$rawname\->{$field}");
                    1;
                } || do { $v = 0; push @diag => "# EXCEPTION: ${@}#    WANTED$rawname\->{$field}\n" };
            }
        }
        else {
            eval {
                if($wrap) {
                    if($wrap eq '[') {
                        ($v, @msgs) = _mostly_like([$got->$field], $want->{$key}, "[$rawname\->$field()]");
                    }
                    elsif($wrap eq '{') {
                        ($v, @msgs) = _mostly_like({$got->$field}, $want->{$key}, "{$rawname\->$field()}");
                    }
                }
                else {
                    ($v, @msgs) = _mostly_like($got->$field, $want->{$field}, "$rawname\->$field()");
                }
                1;
            } || do { $v = 0; push @diag => "# EXCEPTION: ${@}#    WANTED$rawname\->$field()\n" };
        }

        $ok &&= $v;
        push @diag => @msgs;
    }

    return ($ok, @diag);
}

1;
