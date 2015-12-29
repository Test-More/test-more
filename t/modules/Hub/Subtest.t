use strict;
use warnings;
BEGIN { require "t/tools.pl" };

use Test2::Hub::Subtest;
use Carp qw/croak/;

my %TODO;

sub def {
    my ($func, @args) = @_;

    my @caller = caller(0);

    $TODO{$caller[0]} ||= [];
    push @{$TODO{$caller[0]}} => [$func, \@args, \@caller];
}

sub do_def {
    my $for = caller;
    my $tests = delete $TODO{$for} or croak "No tests to run!";

    for my $test (@$tests) {
        my ($func, $args, $caller) = @$test;

        my ($pkg, $file, $line) = @$caller;

# Note: The '&' below is to bypass the prototype, which is important here.
        eval <<"        EOT" or die $@;
package $pkg;
# line $line "(eval in DeferredTests) $file"
\&$func(\@\$args);
1;
        EOT
    }
}

my $ran = 0;
my $event;

my $one = Test2::Hub::Subtest->new(
    nested => 3,
);

ok($one->isa('Test2::Hub'), "inheritence");

{
    no warnings 'redefine';
    local *Test2::Hub::process = sub { $ran++; (undef, $event) = @_; 'P!' };
    use warnings;

    my $ok = Test2::Event::Ok->new(
        pass => 1,
        name => 'blah',
        trace => Test2::Util::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']),
    );

    def is => ($one->process($ok), 'P!', "processed");
    def is => ($ran, 1, "ran the mocked process");
    def is => ($event, $ok, "got our event");
    def is => ($event->nested, 3, "nested was set");
    def is => ($one->bailed_out, undef, "did not bail");

    $ran = 0;
    $event = undef;

    my $bail = Test2::Event::Bail->new(
        message => 'blah',
        trace => Test2::Util::Trace->new(frame => [__PACKAGE__, __FILE__, __LINE__, 'xxx']),
    );

    def is => ($one->process($bail), 'P!', "processed");
    def is => ($ran, 1, "ran the mocked process");
    def is => ($event, $bail, "got our event");
    def is => ($event->nested, 3, "nested was set");
    def is => ($one->bailed_out, $event, "bailed");
}

do_def;

$ran = 0;

T2_SUBTEST_WRAPPER: {
    $ran++;
    $one->terminate(100);
    $ran++;
}

is($ran, 1, "did not get past the terminate");

done_testing;
