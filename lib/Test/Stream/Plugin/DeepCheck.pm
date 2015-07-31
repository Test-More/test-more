package Test::Stream::Plugin::DeepCheck;
use strict;
use warnings;

use Test::Stream::Exporter;
default_exports qw/is_deeply mostly_like/;
exports qw{
    match mismatch check
    hash array object meta
    item field call prop
    end_items filter_items
    T F D
};
no Test::Stream::Exporter;

use Carp qw/croak/;

use Test::Stream::DeepCheck qw/compare/;
use Test::Stream::Context qw/context/;

use Test::Stream::DeepCheck::Build;
use Test::Stream::DeepCheck::Array;
use Test::Stream::DeepCheck::Code;
use Test::Stream::DeepCheck::Hash;
use Test::Stream::DeepCheck::Meta;
use Test::Stream::DeepCheck::Object;
use Test::Stream::DeepCheck::Regex;
use Test::Stream::DeepCheck::Value;

sub is_deeply($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my ($ok, @d) = compare($got, $exp, 1);

    $ctx->ok($ok, $name, [@d, @diag]);
    $ctx->release;
    return $ok;
}

sub mostly_like($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my ($ok, @d) = compare($got, $exp, 0);

    $ctx->ok($ok, $name, [@d, @diag]);
    $ctx->release;
    return $ok;
}

sub meta(&)   { build('Test::Stream::DeepCheck::Meta',   @_) }
sub hash(&)   { build('Test::Stream::DeepCheck::Hash',   @_) }
sub array(&)  { build('Test::Stream::DeepCheck::Array',  @_) }
sub object(&) { build('Test::Stream::DeepCheck::Object', @_) }

my $T = Test::Stream::DeepCheck::Code->new(code => sub { $_[0]         ? 1 : 0 }, name => 'TRUE');
my $F = Test::Stream::DeepCheck::Code->new(code => sub { $_[0]         ? 0 : 1 }, name => 'FALSE');
my $D = Test::Stream::DeepCheck::Code->new(code => sub { defined $_[0] ? 1 : 0 }, name => 'DEFINED');
sub T() { $T }
sub F() { $F }
sub D() { $D }

sub match($) {
    my @caller = caller;
    return Test::Stream::DeepCheck::Regex->new(
        file       => $caller[1],
        start_line => $caller[2],
        end_line   => $caller[2],
        pattern    => $_[0],
    );
}

sub mismatch($) {
    my @caller = caller;
    return Test::Stream::DeepCheck::Regex->new(
        file       => $caller[1],
        start_line => $caller[2],
        end_line   => $caller[2],
        negate     => 1,
        pattern    => $_[0],
    );
}

sub check(&;$) {
    my @caller = caller;
    return Test::Stream::DeepCheck::Code->new(
        file       => $caller[1],
        start_line => $caller[2],
        end_line   => $caller[2],
        code       => $_[0],
        name       => $_[1],
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

sub end_items() {
    my $build = get_build() || croak "No current build!";

    croak "'$build' does not support 'end_items'"
        unless $build->can('strict_end');

    croak "'strict_end' should only ever be called in void context"
        if defined wantarray;

    $build->set_strict_end(1);
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
        {
            expect     => $expect,
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        }
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
        {
            expect     => $expect,
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        }
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
    push @args => {
        expect     => $expect,
        file       => $caller[1],
        start_line => $caller[2],
        end_line   => $caller[2],
    };

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
        {
            expect     => $expect,
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        }
    );
}

1;
