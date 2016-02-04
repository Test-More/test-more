use Test2::Bundle::Extended -target => 'Test2::Workflow';
use Test2::Tools::Spec;
use Test2::Util qw/get_tid/;

use Test2::Workflow qw/workflow_var/;

imported_ok(qw{
    describe cases
    before_all after_all around_all

    tests it mini iso async miso masync
    before_each after_each around_each

    case
    before_case after_case around_case
});

before_each bef => sub { ok(1, "before") };
around_each arr => sub {
    ok(1, "prefix");
    $_[0]->();
    ok(1, "postfix");
};
after_each  aft => sub { ok(1, "after") };

before_all 'pre-all' => sub {
    ok(1, 'pre all');
};

before_case 'haha' => sub {
    ok(1, 'before case');
};

case x => sub { ok(1, 'inside x') };
case y => sub { ok(1, 'inside y') };

describe "xxx" => sub {
    tests foo => sub {
        ok(1, "Boooya!");
        is(workflow_var('foo'), 'bar', "Got variable");
    };

    before_each "ooo" => sub {
        workflow_var foo => 'bar';
        is(workflow_var('foo'), 'bar', "Set variable");
        ok(1, "bleh");
    };

    after_each "ooo" => sub {
        ok(1, "bleh");
    };
};

tests fail1 => { todo => 'this is todo' }, sub {
    ok(1, "pass");
    ok(0, "fail");
    ok(1, "pass");
};

tests fail2 => { skip => 'this will break' }, sub {
    die "oops";
};

my $x = 1;
miso isolated_a => sub {
    is($x, 1, "x unchanged (iso a) $$ " . get_tid);
    $x = 2;
};

miso isolated_b => sub {
    is($x, 1, "x unchanged (iso b) $$ " . get_tid);
    $x = 2;
};

masync async_a => sub {
    is($x, 1, "x unchanged (async a) $$ " . get_tid);
};

masync async_b => sub {
    is($x, 1, "x unchanged (async b) $$ " . get_tid);
};

miso mock => sub {
    mock 'Foo::Bar' => (
        add => [ foo => sub { 'foo' } ],
    );
    is(Foo::Bar::foo(), 'foo', "mocked");
};


done_testing;
