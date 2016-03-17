use strict;
use warnings;
use Test2::Bundle::Extended;
use Test2::Tools::Spec;

ok(1, 'outside');

my $g = describe foo => sub {
    before_all start => sub { ok(1, 'start') };

    around_all al => sub {
        my $cont = shift;
        ok(1, 'al start');
        $cont->();
        ok(1, 'al end');
    };

    after_all  end   => sub { ok(1, 'end')   };

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

    test bar => sub {
        ok(1, "inside 1");
    };

    test baz => sub {
        ok(1, "inside 2");
    };
};

require Test2::Workflow::Runner;
my $r = Test2::Workflow::Runner->new(task => $g);
$r->run;

done_testing;

1;
