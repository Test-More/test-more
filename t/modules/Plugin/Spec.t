use Test::Stream qw/-SpecTester/;
use Test::Stream::Context qw/context/;
use Test::Stream::Workflow qw/workflow_var/;

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
    tests foo => {fork => 1}, sub {
        ok(1, "Boooya! $$");
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

done_testing;
