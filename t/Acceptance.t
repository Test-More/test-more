use strict;
use warnings;
use Test2::Bundle::Extended;
use Test2::Tools::Spec;

use Test2::Workflow::Runner;

use Test2::Util qw/get_tid/;

my $g = describe foo => sub {
    before_all start => sub { ok(1, 'start') };

    around_all al => sub {
        my $cont = shift;
        ok(1, 'al start');
        $cont->();
        ok(1, 'al end');
    };

    after_all end => sub { ok(1, 'end')   };

    before_each bef => sub { ok(1, 'a') };

    around_each arr => sub {
        my $cont = shift;
        ok(1, 'ar start');
        $cont->();
        ok(1, 'ar end');
    };

    after_each  aft => sub { ok(1, 'z') };

    case c1 => sub { ok(1, 'in c1') };
    case c2 => sub { ok(1, 'in c2') };

    before_case bc => sub { ok(1, 'in bc') };
    around_case arc => sub {
        my $cont = shift;
        ok(1, 'arc start');
        $cont->();
        ok(1, 'arc end');
    };
    after_case  ac => sub { ok(1, 'in ac') };

    tests bar => {iso => 1}, sub {
        ok(1, "inside bar pid $$ - tid " . get_tid());
    };

    tests baz => sub {
        ok(1, "inside baz pid $$ - tid " . get_tid());
    };

    tests uhg => sub {
        my $todo = todo "foo todo";
        ok(0, 'xxx');
    };

    tests bug => {todo => 'a bug'}, sub {
        ok(0, 'fail');
    };

    tests broken => {skip => 'will break things'}, sub {
        warn "\n\n**** You should not see this! ****\n\n";
        print "not ok - You should not see this\n";
        exit 255;
    };

    describe nested => {iso => 1}, sub {
        before_each n1_be => sub { ok(1, 'nested before') };
        after_each  n1_ae => sub { ok(1, 'nested after') };

        tests n1 => sub { ok(1, 'nested 1') };
        tests n2 => sub { ok(1, 'nested 2') };
    };
};

my $r1 = Test2::Workflow::Runner->new(task => $g, no_threads => 1);
$r1->run;

my $r2 = Test2::Workflow::Runner->new(task => $g, no_fork => 1);
$r2->run;

my $r3 = Test2::Workflow::Runner->new(task => $g, no_fork => 1, no_threads => 1);
$r3->run;

tests on_root => sub { ok(1, "in root") };

{
    package Foo::Bar;

    sub foo { 'xxx' }
}

describe in_root => sub {
    is(Foo::Bar->foo, 'xxx', "not mocked");

    mock 'Foo::Bar' => (
        override => [
            foo => sub { 'foo' },
        ],
    );

    is(Foo::Bar->foo, 'foo', "mocked");

    tests on_root_a => sub {
        ok(1, "in root");
        is(Foo::Bar->foo, 'foo', "mocked");
    };
    tests on_root_b => sub { ok(1, "in root") };
    tests on_root_c => sub { ok(1, "in root") };
    tests on_root_d => sub { ok(1, "in root") };
};

is(Foo::Bar->foo, 'xxx', "not mocked");

done_testing;

1;
