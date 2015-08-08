package Test::Stream::Delta;
use strict;
use warnings;

use Test::Stream::HashBase(
    accessors => [qw/verified id got chk children dne exception/]
);

use Test::Stream::Table();
use Test::Stream::Context();

use Scalar::Util qw/reftype blessed/;

# 'CHECK' constant would not work, but I like exposing 'check()' to people
# using this class.
BEGIN {
    no warnings 'once';
    *check = \&chk;
    *set_check = \&set_chk;
}

sub init {
    my $self = shift;

    # Allow 'check' as an argument
    $self->{+CHK} = delete $self->{check}
        if exists($self->{check}) && !exists($self->{+CHK});
}

sub render_got {
    my $self = shift;

    my $got = $self->{+GOT};
    my $dne = $self->{+DNE};

    my $exp = $self->{+EXCEPTION};
    if ($exp) {
        chomp($exp = "$exp");
        $exp =~ s/\n.*$//g;
    }

    return "<EXCEPTION: $exp>" if $exp;

    return '<DOES NOT EXIST>' if $dne && $dne eq 'got';

    return '<UNDEF>' unless defined $got;

    return "$got" unless ref $got;

    my $type = reftype($got);
    my $class = blessed($got);

    return "<$type>" unless $class;
    return "<$class>";
}

sub render_check {
    my $self = shift;

    my $check = $self->{+CHK};
    my $dne = $self->{+DNE};

    return '<DOES NOT EXIST>' if $dne && $dne eq 'check';

    return '<UNDEF>' unless defined $check;

    return $check->render;
}

sub _full_id {
    my ($type, $id) = @_;
    return "<$id>" if !$type || $type eq 'META';
    return "{$id}" if $type eq 'HASH';
    return "[$id]" if $type eq 'ARRAY';
    return "$id()" if $type eq 'METHOD';
    return "<$id>";
}

sub _arrow_id {
    my ($path, $type) = @_;
    return ' '  if $type eq 'META';       # Meta gets a space, not an arrow
    return '->' if $type eq 'METHOD';     # Method always needs an arrow
    return '->' if $path =~ m/(>|\(\))$/; # Need an arrow after meta, or after a method
    return '->' if $path eq '$VAR';       # Need an arrow after the initial ref
    return '';                            # No arrow needed
}

sub _join_id {
    my ($path, $parts) = @_;
    my ($type, $key) = @$parts;

    my $id   = _full_id($type, $key);
    my $join = _arrow_id($path, $type);

    return "${path}${join}${id}";
}

sub should_show {
    my $self = shift;
    return 1 unless $self->verified;
    my $check = $self->check || return 0;
    return 0 unless $check->lines;
    my $file = $check->file || return 0;

    my $ctx = Test::Stream::Context::context();
    return 0 unless $file eq $ctx->debug->file;

    return 1;
}

my $NOTED_MAX;
sub table {
    my $delta = shift;

    my @deltas;

    my $verified = $delta->verified;

    my @queue = (['', $delta]);

    my $max = exists $ENV{TS_MAX_DELTA} ? $ENV{TS_MAX_DELTA} : 25;

    my $count = 0;
    while (my $set = shift @queue) {
        my ($path, $delta) = @$set;
        next unless $delta;

        $count++ unless $delta->verified;
        last if $max && $count && $count > $max;

        push @deltas => [$path, $delta] if $delta->should_show;

        my $children = $delta->children || next;
        next unless @$children;

        my @new;
        for my $child (@$children) {
            my $cpath = _join_id($path, $child->id);
            push @new => [$cpath, $child];
        }
        unshift @queue => @new if @new;
    }

    my @header = (qw/PATH LNs GOT OP CHECK LNs/);

    my @rows;
    for my $set (@deltas) {
        my ($path, $d) = @$set;
        my $check = $d->chk;
        my $got_dne = $d->dne && $d->dne eq 'got';

        my $op = $check ? $check->operator($got_dne ? () : $d->got) : '!exists';
        my $rc = $d->render_check;
        my $rg = $d->render_got;
        my $id = $path;

        my $dlns = ($check && $check->lines) ? join(', ', @{$check->lines}) : '';

        my @glns = ($check && !$got_dne) ? $check->got_lines($d->got) : ();
        my $glns = @glns ? join(', ', @glns) : '';

        push @rows => [$id, $glns, $rg, $op, $rc, $dlns];
    }

    my @out = Test::Stream::Table::table(
        header   => \@header,
        rows     => \@rows,
        collapse => 1,
    );

    push @out => (
        "************************************************************",
        sprintf("* Stopped after %-42.42s *", "$max differences."),
        "* Set the TS_MAX_DELTA environment var to raise the limit. *",
        "* Set it to 0 for no limit.                                *",
        "************************************************************",
    ) if $max && $count && $count > $max && !$NOTED_MAX++;

    return @out;
}

1;
