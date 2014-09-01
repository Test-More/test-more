package Test::More::Tools;
use strict;
use warnings;

use Test::Provider::Context;

use Test::Stream::Exporter;
exports qw/tbt/;
Test::Stream::Exporter->cleanup;

use Test::Stream::Util qw/try protect is_regex/;
use Scalar::Util qw/blessed/;

sub tbt() { __PACKAGE__ }

# Bad, these are not comparison operators. Should we include more?
my %CMP_OK_BL    = map { ( $_, 1 ) } ( "=", "+=", ".=", "x=", "^=", "|=", "||=", "&&=", "...");
my %NUMERIC_CMPS = map { ( $_, 1 ) } ( "<", "<=", ">", ">=", "==", "!=", "<=>" );

sub cmp_check {
    my($class, $got, $type, $expect) = @_;

    my $ctx = context();
    $ctx->throw("$type is not a valid comparison operator in cmp_check()")
        if $CMP_OK_BL{$type};

    my ($p, $file, $line) = $ctx->call;

    my $test;
    my ($success, $error) = try {
        # This is so that warnings come out at the caller's level
        ## no critic (BuiltinFunctions::ProhibitStringyEval)
        eval qq[
#line $line "$file"
\$test = \$got $type \$expect;
1;
        ] || die $@;
    };

    my @diag;
    push @diag => <<"    END" unless $success;
An error occurred while using $type:
------------------------------------
$error
------------------------------------
    END

    unless($test) {
        # Treat overloaded objects as numbers if we're asked to do a
        # numeric comparison.
        my $unoverload = $NUMERIC_CMPS{$type}
            ? '_unoverload_num'
            : '_unoverload_str';

        $class->$unoverload( \$got, \$expect );

        if( $type =~ /^(eq|==)$/ ) {
            push @diag => $class->_is_diag( $got, $type, $expect );
        }
        elsif( $type =~ /^(ne|!=)$/ ) {
            push @diag => $class->_isnt_diag( $got, $type );
        }
        else {
            push @diag => $class->_cmp_diag( $got, $type, $expect );
        }
    }

    return($test, @diag);
}

sub is_eq {
    my($class, $got, $expect) = @_;

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;
        return ($test, $test ? () : $class->_is_diag($got, 'eq', $expect));
    }

    return $class->cmp_check($got, 'eq', $expect);
}

sub is_num {
    my($class, $got, $expect) = @_;

    if( !defined $got || !defined $expect ) {
        # undef only matches undef and nothing else
        my $test = !defined $got && !defined $expect;
        return ($test, $test ? () : $class->_is_diag($got, '==', $expect));
    }

    return $class->cmp_check($got, '==', $expect);
}

sub isnt_eq {
    my($class, $got, $dont_expect) = @_;

    if( !defined $got || !defined $dont_expect ) {
        # undef only matches undef and nothing else
        my $test = defined $got || defined $dont_expect;
        return ($test, $test ? () : $class->_isnt_diag($got, 'ne'));
    }

    return $class->cmp_check($got, 'ne', $dont_expect);
}

sub isnt_num {
    my($class, $got, $dont_expect) = @_;

    if( !defined $got || !defined $dont_expect ) {
        # undef only matches undef and nothing else
        my $test = defined $got || defined $dont_expect;
        return ($test, $test ? () : $class->_isnt_diag($got, '!='));
    }

    return $class->cmp_check($got, '!=', $dont_expect);
}

sub regex_check {
    my($class, $thing, $regex, $cmp) = @_;

    return (0, "    '$regex' doesn't look much like a regex to me.")
        unless is_regex($regex);

    my $ctx = context();
    my ($p, $file, $line) = $ctx->call;

    my $test;
    my $mock = qq{#line $line "$file"\n};

    my @warnings;
    my ($success, $error) = try {
        # No point in issuing an uninit warning, they'll see it in the diagnostics
        no warnings 'uninitialized';
        ## no critic (BuiltinFunctions::ProhibitStringyEval)
        eval $mock . q{$test = $thing =~ $regex ? 1 : 0; 1} || die $@;
    };

    return (0, "Exception: $error") unless $success;

    my $negate = $cmp eq '!~';

    $test = !$test if $negate;

    unless($test) {
        $thing = defined $thing ? "'$thing'" : 'undef';
        my $match = $negate ? "matches" : "doesn't match";
        my $diag = sprintf(qq{               \%s\n \%13s '\%s'\n}, $thing, $match, $regex);
        return (0, $diag);
    }

    return (1);
}

sub can_check {
    my ($us, $proto, $class, @methods) = @_;

    my @diag;
    for my $method (@methods) {
        my $ok;
        my ($success, $error) = try { $ok = $proto->can($method) };
        if ($success) {
            push @diag => "    $class\->can('$method') failed" unless $ok;
        }
        else {
            push @diag => "    $class\->can('$method') failed with an exception:\n$error"
        }
    }

    return (!@diag, @diag)
}







sub _unoverload_str {
    my $class = shift;
    return $class->_unoverload(q[""], @_);
}

sub _unoverload_num {
    my $class = shift;

    $class->_unoverload('0+', @_);

    for my $val (@_) {
        next unless $class->_is_dualvar($$val);
        $$val = $$val + 0;
    }

    return;
}

# This is a hack to detect a dualvar such as $!
sub _is_dualvar {
    my($class, $val) = @_;

    # Objects are not dualvars.
    return 0 if ref $val;

    no warnings 'numeric';
    my $numval = $val + 0;
    return ($numval != 0 and $numval ne $val ? 1 : 0);
}

sub _unoverload {
    my $class = shift;
    my $type  = shift;

    protect { require overload };

    foreach my $thing (@_) {
        if (blessed $$thing) {
            if (my $string_meth = overload::Method($$thing, $type)) {
                $$thing = $$thing->$string_meth();
            }
        }
    }

    return;
}

sub _diag_fmt {
    my( $class, $type, $val ) = @_;

    if( defined $$val ) {
        if( $type eq 'eq' or $type eq 'ne' ) {
            # quote and force string context
            $$val = "'$$val'";
        }
        else {
            # force numeric context
            $class->_unoverload_num($val);
        }
    }
    else {
        $$val = 'undef';
    }

    return;
}

sub _is_diag {
    my( $class, $got, $type, $expect ) = @_;

    $class->_diag_fmt( $type, $_ ) for \$got, \$expect;

    return <<"DIAGNOSTIC";
         got: $got
    expected: $expect
DIAGNOSTIC
}

sub _isnt_diag {
    my( $class, $got, $type ) = @_;

    $class->_diag_fmt( $type, \$got );

    return <<"DIAGNOSTIC";
         got: $got
    expected: anything else
DIAGNOSTIC
}


sub _cmp_diag {
    my( $class, $got, $type, $expect ) = @_;

    $got    = defined $got    ? "'$got'"    : 'undef';
    $expect = defined $expect ? "'$expect'" : 'undef';

    return <<"DIAGNOSTIC";
    $got
        $type
    $expect
DIAGNOSTIC
}


1;

__END__



