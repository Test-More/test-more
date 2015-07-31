package Test::Stream::Plugin::Tester;
use strict;
use warnings;

use Test::Stream::Plugin::DeepCheck(
    qw/check/,
    prop         => {-as => 'eprop'},
    call         => {-as => 'ecall'},
    field        => {-as => 'efield'},
    filter_items => {-as => 'filter_events'},
    end_items    => {-as => 'end_events'},
);

use Test::Stream::Exporter;
default_exports qw{
    events_are
    events
    event
    eprop efield ecall
    filter_events end_events
};
no Test::Stream::Exporter;

use Carp qw/croak/;
use Scalar::Util qw/reftype/;

use Test::Stream::DeepCheck qw/compare/;
use Test::Stream::Context qw/context/;

use Test::Stream::Block;
use Test::Stream::DeepCheck::Build;
use Test::Stream::DeepCheck::Event;
use Test::Stream::DeepCheck::Events;
use Test::Stream::DeepCheck::Meta::Event;

sub events_are($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my ($ok, @d) = compare(
        $got, $exp, 0,
        {
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        },
    );

    $ctx->ok($ok, $name, [@d, @diag]);
    $ctx->release;
    return $ok;
}

sub events(&) { build('Test::Stream::DeepCheck::Events', @_) }

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
        $event = Test::Stream::DeepCheck::Event->new(
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        );
    }
    elsif (!ref $spec) {
        croak "'$spec' is not a valid event specification"
    }
    elsif (reftype($spec) eq 'CODE') {
        $event = build('Test::Stream::DeepCheck::Event', $spec);
        my $block = Test::Stream::Block->new(coderef => $spec, caller => \@caller);
        $event->set_file($block->file);
        $event->set_start_line($block->start_line);
        $event->set_end_line($block->end_line);
    }
    else {
        my $refcheck = Test::Stream::DeepCheck::Hash->new(
            fields => { map { $_ => {expect => $spec->{$_}} } keys %$spec },
            order      => [sort keys %$spec],
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        );
        $event = Test::Stream::DeepCheck::Event->new(
            refcheck   => $refcheck,
            file       => $caller[1],
            start_line => $caller[2],
            end_line   => $caller[2],
        );
    }

    my $tcheck = check { $_[0]->isa($type) } "isa($intype)";
    $event->add_prop('this' => {expect => $tcheck});

    return $event if defined wantarray;

    my $build = get_build() || croak "No current build!";
    $build->add_item({expect => $event});
}

1;
