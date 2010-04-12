#!/usr/bin/perl

# A demonstration of how you'd implement Test::NoWarnings in TB2

use strict;
use warnings;

BEGIN {
    package Test::NoWarnings;

    require Test::Simple;
    use Test::Builder2::Mouse::Role;

    my @Warnings;

    before stream_start => sub {
        $SIG{__WARN__} = sub {
            push @Warnings, @_;
        };
    };

    around "set_plan" => sub {
        my $orig = shift;
        my $self = shift;
        my %args = @_;

        $args{tests}++ if defined $args{tests};

        $self->$orig(%args);
    };

    before stream_end => sub {
        my $self = shift;
        $self->ok( !@Warnings, "no warnings" );
    };

    Test::NoWarnings->meta->apply(Test::Simple->builder);
}

require Test::Builder2::Streamer::Debug;
my $builder = Test::Simple->builder;
$builder->formatter->streamer(Test::Builder2::Streamer::Debug->new);

require Test::Simple;
Test::Simple->import( tests => 2 );

ok(1, "pass 1");
warn "Wibble";
ok(1, "pass 2");

# XXX TB2 doesn't implicitly call stream_end yet
$builder->stream_end();

print "1..2\n";
print "ok 1 - count correct\n" if $builder->history->counter->get == 3;
print "ok 2 - nowarnings test failed properly\n" if !$builder->history->results->[2];
