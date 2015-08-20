package Test::Stream::Plugin::Compare;
use strict;
use warnings;

use Test::Stream::Exporter;
default_exports qw/is like/;
exports qw{
    match mismatch check
    hash array object meta
    item field call prop
    end filter_items
    T F D DNE
    event
};
no Test::Stream::Exporter;

use Carp qw/croak/;
use Scalar::Util qw/reftype blessed/;

use Test::Stream::Block;

use Test::Stream::Compare qw/-all/;
use Test::Stream::Context qw/context/;

use Test::Stream::Compare::Array;
use Test::Stream::Compare::Custom;
use Test::Stream::Compare::DNE;
use Test::Stream::Compare::Event;
use Test::Stream::Compare::Hash;
use Test::Stream::Compare::Meta;
use Test::Stream::Compare::Object;
use Test::Stream::Compare::Pattern;
use Test::Stream::Compare::Ref;
use Test::Stream::Compare::Scalar;
use Test::Stream::Compare::Value;
use Test::Stream::Compare::Wildcard;

sub is($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&strict_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub like($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&relaxed_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub meta(&)   { build('Test::Stream::Compare::Meta',   @_) }
sub hash(&)   { build('Test::Stream::Compare::Hash',   @_) }
sub array(&)  { build('Test::Stream::Compare::Array',  @_) }
sub object(&) { build('Test::Stream::Compare::Object', @_) }

my $T = Test::Stream::Compare::Custom->new(code => sub { $_[0]         ? 1 : 0 }, name => 'TRUE()',    operator => 'TRUE');
my $F = Test::Stream::Compare::Custom->new(code => sub { $_[0]         ? 0 : 1 }, name => 'FALSE()',   operator => 'FALSE');
my $D = Test::Stream::Compare::Custom->new(code => sub { defined $_[0] ? 1 : 0 }, name => 'DEFINED()', operator => 'DEFINED');
sub T() { $T }
sub F() { $F }
sub D() { $D }

sub DNE() {
    my @caller = caller;
    Test::Stream::Compare::DNE->new(
        file  => $caller[1],
        lines => [$caller[2]],
    );
}

sub match($) {
    my @caller = caller;
    return Test::Stream::Compare::Pattern->new(
        file    => $caller[1],
        lines   => [$caller[2]],
        pattern => $_[0],
    );
}

sub mismatch($) {
    my @caller = caller;
    return Test::Stream::Compare::Pattern->new(
        file    => $caller[1],
        lines   => [$caller[2]],
        negate  => 1,
        pattern => $_[0],
    );
}

sub check {
    my $code = pop;
    my $cname = pop;
    my $op = pop;

    my @caller = caller;
    return Test::Stream::Compare::Custom->new(
        file     => $caller[1],
        lines    => [$caller[2]],
        code     => $code,
        name     => $cname,
        operator => $op,
    );
}

sub filter_items(&) {
    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support filters"
        unless $build->can('add_filter');

    croak "'filter_items' should only ever be called in void context"
        if defined wantarray;

    $build->add_filter(@_);
}

sub end() {
    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support 'end_items'"
        unless $build->can('ending');

    croak "'end' should only ever be called in void context"
        if defined wantarray;

    $build->set_ending(1);
}

sub call($$) {
    my ($name, $expect) = @_;
    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support method calls"
        unless $build->can('add_call');

    croak "'call' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    $build->add_call(
        $name,
        Test::Stream::Compare::Wildcard->new(
            expect => $expect,
            file   => $caller[1],
            lines  => [$caller[2]],
        ),
    );
}

sub prop($$) {
    my ($name, $expect) = @_;
    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support meta-checks"
        unless $build->can('add_prop');

    croak "'prop' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    $build->add_prop(
        $name,
        Test::Stream::Compare::Wildcard->new(
            expect => $expect,
            file   => $caller[1],
            lines  => [$caller[2]],
        ),
    );
}

sub item($;$) {
    my @args   = @_;
    my $expect = pop @args;

    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support array item checks"
        unless $build->can('add_item');

    croak "'item' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    push @args => Test::Stream::Compare::Wildcard->new(
        expect => $expect,
        file   => $caller[1],
        lines  => [$caller[2]],
    );

    $build->add_item(@args);
}

sub field($$) {
    my ($name, $expect) = @_;

    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support hash field checks"
        unless $build->can('add_field');

    croak "'field' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    $build->add_field(
        $name,
        Test::Stream::Compare::Wildcard->new(
            expect => $expect,
            file   => $caller[1],
            lines  => [$caller[2]],
        ),
    );
}

sub event($;$) {
    my ($intype, $spec) = @_;

    my @caller = caller;

    croak "type is required" unless $intype;

    my $type;
    if ($intype =~ m/^\+(.*)$/) {
        $type = $1;
    }
    else {
        $type = "Test::Stream::Event::$intype";
    }

    my $event;
    if (!$spec) {
        $event = Test::Stream::Compare::Event->new(
            etype => $intype,
            file  => $caller[1],
            lines => [$caller[2]],
        );
    }
    elsif (!ref $spec) {
        croak "'$spec' is not a valid event specification"
    }
    elsif (reftype($spec) eq 'CODE') {
        $event = build('Test::Stream::Compare::Event', $spec);
        my $block = Test::Stream::Block->new(coderef => $spec, caller => \@caller);
        $event->set_file($block->file);
        $event->set_lines([$block->start_line, $block->end_line]);
        $event->set_etype($intype),
    }
    else {
        my $refcheck = Test::Stream::Compare::Hash->new(
            inref => $spec,
            file  => $caller[1],
            lines => [$caller[2]],
        );
        $event = Test::Stream::Compare::Event->new(
            refcheck => $refcheck,
            file     => $caller[1],
            lines    => [$caller[2]],
            etype => $intype,
        );
    }

    my $tcheck = Test::Stream::Compare::Custom->new(
        file  => $caller[1],
        lines => [$caller[2]],
        code  => sub {},
        name  => "isa($intype)",
    );

    $event->add_prop('this' => $tcheck);

    return $event if defined wantarray;

    my $build = get_build() || croak "No current build!";
    $build->add_item($event);
}

sub _type {
    my ($thing) = @_;
    return '' unless defined $thing;

    my $rf = ref $thing;
    my $rt = reftype $thing;

    return '' unless $rf || $rt;
    return 'REGEXP' if $rf =~ m/Regex/i;
    return 'REGEXP' if $rt =~ m/Regex/i;
    return $rt || '';
}

sub strict_convert {
    my $thing = shift;

    if ($thing && blessed($thing) && $thing->isa('Test::Stream::Compare')) {
        return $thing unless $thing->isa('Test::Stream::Compare::Wildcard');
        my $newthing = strict_convert($thing->expect);
        $newthing->set_file($thing->file)   unless $newthing->file;
        $newthing->set_lines($thing->lines) unless $newthing->lines;
        return $newthing;
    }

    my $type = _type($thing);

    return Test::Stream::Compare::Array->new(inref => $thing, ending => 1)
        if $type eq 'ARRAY';

    return Test::Stream::Compare::Hash->new(inref => $thing, ending => 1)
        if $type eq 'HASH';

    if ($type eq 'SCALAR') {
        my $nested = strict_convert($$thing);
        return Test::Stream::Compare::Scalar->new(item => $nested)
    }

    return Test::Stream::Compare::Ref->new(input => $thing)
        if $type;

    return Test::Stream::Compare::Value->new(input => $thing);
}

sub relaxed_convert {
    my $thing = shift;

    if ($thing && blessed($thing) && $thing->isa('Test::Stream::Compare')) {
        return $thing unless $thing->isa('Test::Stream::Compare::Wildcard');
        my $newthing = relaxed_convert($thing->expect);
        $newthing->set_file($thing->file)   unless $newthing->file;
        $newthing->set_lines($thing->lines) unless $newthing->lines;
        return $newthing;
    }

    my $type = _type($thing);

    return Test::Stream::Compare::Array->new(inref => $thing)
        if $type eq 'ARRAY';

    return Test::Stream::Compare::Hash->new(inref => $thing)
        if $type eq 'HASH';

    return Test::Stream::Compare::Pattern->new(pattern => $thing)
        if $type eq 'REGEXP';

    return Test::Stream::Compare::Custom->new(code => $thing)
        if $type eq 'CODE';

    if ($type eq 'SCALAR') {
        my $nested = relaxed_convert($$thing);
        return Test::Stream::Compare::Scalar->new(item => $nested)
    }

    return Test::Stream::Compare::Ref->new(input => $thing)
        if $type;

    return Test::Stream::Compare::Value->new(input => $thing);
}


1;
