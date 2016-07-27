use Test2::Bundle::Extended;
use Test2::Tools::Spec qw/:ALL/;

spec_defaults case  => (iso => 1, async => 1);
spec_defaults tests => (iso => 1, async => 1);

my $orig = $$;

tests outside => sub {
    isnt($$, $orig, "In child (lexial)");
};

describe wrapper => sub {
    case foo => sub {
        isnt($$, $orig, "In child (inherited)")
    };

    case 'bar', {iso => 0, async => 0} => sub {
        is($$, $orig, "In orig (overriden)")
    };

    tests a => sub { ok(1, 'stub') };
    tests b => sub { ok(1, 'stub') };

    my $x = describe nested => sub {
        tests nested_t => sub { ok(0, 'Should not see this') };
    };

    tests nested => sub {
        ok(!$x->primary->[0]->iso, "Did not inherit when captured");
        ok(!$x->primary->[0]->async, "Did not inherit when captured");
    };
};

done_testing;
