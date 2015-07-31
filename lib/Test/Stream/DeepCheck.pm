package Test::Stream::DeepCheck;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype looks_like_number/;
use List::Util qw/max/;

use Carp qw/croak confess/;

use Test::Stream::Util qw/term_size/;

use Test::Stream::Exporter;
exports qw/compare convert stringify deeptype fail_table/;
no Test::Stream::Exporter;

use Test::Stream::DeepCheck::State;

sub compare {
    my ($got, $exp, $strict, $debug) = @_;

    my $state = Test::Stream::DeepCheck::State->new(strict => $strict);

    $exp = convert(
        expect => $exp,
        state  => $state,
        debug  => $debug,
    );

    my $res = $exp->check($got, "", $state);

    return $res->ok;
}

# These all require this module, the cycle is not avoidable. This makes it easy
# to load them all at once, but only when needed, and require is only called
# once per module. Calling require on every call to 'convert' is suprisingly
# expensive in profiling.
my $LOAD;
$LOAD = sub {
    require Test::Stream::DeepCheck::Array;
    require Test::Stream::DeepCheck::Hash;
    require Test::Stream::DeepCheck::Regex;
    require Test::Stream::DeepCheck::Code;
    require Test::Stream::DeepCheck::Value;
    $LOAD = undef;
};

sub convert {
    my %spec = @_;

    my $exp        = delete $spec{expect};
    my $state      = delete $spec{state};
    my $file       = delete $spec{file};
    my $start_line = delete $spec{start_line};
    my $end_line   = delete $spec{end_line};
    my $debug      = delete $spec{debug} || {
        defined($file)       ? (file       => $file)       : (),
        defined($start_line) ? (start_line => $start_line) : (),
        defined($end_line)   ? (end_line   => $end_line)   : (),
    };

    if (my @keys = keys %spec) {
        my $error = "Invalid convert keys: (" . join( ', ', @keys ) . ")";
        confess $error;
    }

    return $exp
        if blessed($exp) && $exp->isa('Test::Stream::DeepCheck::Check');

    $LOAD->() if $LOAD;

    my $type = deeptype($exp);

    return Test::Stream::DeepCheck::Array->new(
        %$debug,
        items => {map { $_ => {expect => $exp->[$_]} } 0 .. (@$exp - 1)},
        count => scalar @$exp,
    ) if $type eq 'ARRAY';

    return Test::Stream::DeepCheck::Hash->new(
        %$debug,
        fields => { map { $_ => {expect => $exp->{$_}} } keys %$exp },
        order => [sort keys %$exp],
    ) if $type eq 'HASH';

    unless($state->strict) {
        return Test::Stream::DeepCheck::Regex->new(%$debug, pattern => $exp)
            if $type eq 'REGEXP';

        return Test::Stream::DeepCheck::Code->new(%$debug, code => $exp)
            if $type eq 'CODE';
    }

    return Test::Stream::DeepCheck::Value->new(%$debug, val => $exp);
}

# reftype and ref return different things for different versions (with regexp) this tries to get it right
sub deeptype {
    my ($thing) = @_;
    my $rf = ref $thing;
    my $rt = reftype $thing;

    return '' unless $rf || $rt;
    return 'REGEXP' if $rf =~ m/Regex/i;
    return 'REGEXP' if $rt =~ m/Regex/i;
    return $rt || '';
}

sub stringify {
    my ($val) = @_;
    return 'undef' unless defined $val;

    return $val->as_string
        if blessed($val) && $val->isa('Test::Stream::DeepCheck::Check');

    return "$val" if ref $val;
    return "$val" if looks_like_number($val);
    return "'$val'";
}

sub fail_table {
    my %params = @_;

    my $res = $params{res};

    my $id = $params{id} || ' ID ';
    my $title_l = ' GOT ';
    my $title_r = ' EXPECTED ';
    my $max_i = max( 5, length($id));
    my $max_l = max( 5, length($title_l));
    my $max_r = max( 5, length($title_r));

    # the 8 accounts for table bars, comment '#', and some extra chars for
    # safety.
    my $total = term_size() - 8;

    for my $set (@$res) {
        my $i = length($set->id);
        my ($l, $r) = @{$set->summary};

        $max_i = max($max_i, length($i));
        $max_l = max($max_l, length($l));
        $max_r = max($max_r, length($r));
    }

    $max_i = int($total / 3) if $max_i > int($total / 3);

    my $items = $total - $max_i;
    if ($max_l + $max_r > $items) {
        $max_l = int($items / 2);
        $max_r = $max_l;
    }

    my $border = '+' . join( '+', '-' x $max_i, '-' x $max_l, '-' x $max_r ) . '+';
    my $lf = "|\%-${max_i}.${max_i}s|\%-${max_l}.${max_l}s|\%-${max_r}.${max_r}s|";

    return(
        $border,
        sprintf($lf, " $id", $title_l, $title_r),
        $border,
        (map { sprintf($lf, $_->id, @{$_->summary}) } @$res),
        $border,
    );
}

1;
