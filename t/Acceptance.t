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
};

my $r = Test2::Workflow::Runner->new(task => $g);
$r->run;

my $r2 = Test2::Workflow::Runner->new(task => $g, no_fork => 1);
$r2->run;

my $r3 = Test2::Workflow::Runner->new(task => $g, no_fork => 1, no_threads => 1);
$r3->run;

done_testing;

1;
