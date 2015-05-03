use Test::Stream::Shim;
use strict;
use warnings;
use B;

use Test::Stream;
use Test::MostlyLike;
use Test::More tests => 8;
use Test::Builder; # Not loaded by default in modern mode
my $orig = Test::Builder->can('plan');

use Test::Stream::Tester;

my $ran = 0;
no warnings 'redefine';
my $file = __FILE__;
my $line = __LINE__ + 1;
*Test::Builder::plan = sub { my $self = shift; $ran++; $self->$orig(@_) };
use warnings;

my @warnings;
$SIG{__WARN__} = sub { push @warnings => @_ };

events_are(
    intercept {
        plan tests => 2;
        ok(1, "pass");
        ok(0, "fail");
    },
    check {
        event plan => { max => 2 };
        event ok => { effective_pass => 1 };
        event ok => { effective_pass => 0 };
        directive 'end';
    },
);

events_are(
    intercept {
        Test::More->import('tests' => 2);
        ok(1, "pass");
        ok(0, "fail");
    },
    check {
        event plan => { max => 2 };
        event ok => { effective_pass => 1 };
        event ok => { effective_pass => 0 };
        directive 'end';
    },
);

events_are(
    intercept {
        Test::More->import(skip_all => 'damn');
        ok(1, "pass");
        ok(0, "fail");
    },
    check {
        event plan => { max => 0, directive => 'SKIP', reason => 'damn' };
        directive 'end';
    },
);

events_are(
    intercept {
        Test::More->import('no_plan');
        ok(1, "pass");
        ok(0, "fail");
    },
    check {
        event plan => { directive => 'NO PLAN' };
        event ok => { effective_pass => 1 };
        event ok => { effective_pass => 0 };
        directive 'end';
    },
);

is($ran, 4, "We ran our override each time");
mostly_like(
    \@warnings,
    [
        qr{The new sub is 'main::__ANON__' defined in \Q$file\E around line $line},
        undef,
    ],
    "Got the warning once"
);



no warnings 'redefine';
*Test::Builder::plan = sub { };
use warnings;
my $ok;
events_are(
    intercept {
        $ok = eval {
            plan(tests => 1);
            plan(tests => 2);
            ok(1);
            ok(1);
            ok(1);
            done_testing;
            1;
        };
    },
    check {
        event ok => { effective_pass => 1 };
        event ok => { effective_pass => 1 };
        event ok => { effective_pass => 1 };
        event plan => { max => 3 };
        directive 'end';
    },
    "Make sure plan monkeypatching does not effect done_testing"
);

ok($ok, "Did not die");
