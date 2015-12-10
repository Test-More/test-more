use strict;
use warnings;

use Test::Stream::IPC;

my @drivers;
BEGIN { @drivers = Test::Stream::IPC->drivers };

use Test::Stream::Tester;
use Test::Stream::Context qw/context/;
sub tests {
    my ($name, $code) = @_;
    my $ok = eval { $code->(); 1 };
    my $err = $@;
    my $ctx = context();
    $ctx->ok($ok, $name, [$err]);
    $ctx->release;
}

is_deeply(
    \@drivers,
    ['Test::Stream::IPC::Files'],
    "Got default driver"
);

require Test::Stream::IPC::Files;
Test::Stream::IPC::Files->import();
Test::Stream::IPC::Files->import();
Test::Stream::IPC::Files->import();

Test::Stream::IPC->register_drivers(
    'Test::Stream::IPC::Files',
    'Test::Stream::IPC::Files',
    'Test::Stream::IPC::Files',
);

is_deeply(
    [Test::Stream::IPC->drivers],
    ['Test::Stream::IPC::Files'],
    "Driver not added multiple times"
);

tests init_drivers => sub {
    ok( !exception { Test::Stream::IPC->new }, "Found working driver" );

    no warnings 'redefine';
    local *Test::Stream::IPC::Files::is_viable = sub { 0 };
    use warnings;

    like(
        exception { Test::Stream::IPC->new },
        qr/Could not find a viable IPC driver! Aborting/,
        "No viable drivers"
    );

    no warnings 'redefine';
    local *Test::Stream::IPC::Files::is_viable = sub { undef };
    use warnings;
    like(
        exception { Test::Stream::IPC->new },
        qr/Could not find a viable IPC driver! Aborting/,
        "No viable drivers"
    );
};

tests polling => sub {
    ok(!Test::Stream::IPC->polling_enabled, "no polling yet");
    ok(!@Test::Stream::Context::ON_INIT, "no context init hooks yet");

    Test::Stream::IPC->enable_polling;

    ok(1 == @Test::Stream::Context::ON_INIT, "added 1 hook");
    ok(Test::Stream::IPC->polling_enabled, "polling enabled");

    Test::Stream::IPC->enable_polling;

    ok(1 == @Test::Stream::Context::ON_INIT, "Did not add hook twice");
};

for my $meth (qw/send cull add_hub drop_hub waiting is_viable/) {
    my $one = Test::Stream::IPC->new;
    like(
        exception { $one->$meth },
        qr/'\Q$one\E' did not define the required method '$meth'/,
        "Require override of method $meth"
    );
}

tests abort => sub {
    my $one = Test::Stream::IPC->new(no_fatal => 1);
    my ($err, $out) = ("", "");

    {
        local *STDERR;
        local *STDOUT;
        open(STDERR, '>', \$err);
        open(STDOUT, '>', \$out);
        $one->abort('foo');
    }

    is($err, "IPC Fatal Error: foo\n", "Got error");
    is($out, "not ok - IPC Fatal Error\n", "got 'not ok' on stdout");

    ($err, $out) = ("", "");

    {
        local *STDERR;
        local *STDOUT;
        open(STDERR, '>', \$err);
        open(STDOUT, '>', \$out);
        $one->abort_trace('foo');
    }

    is($out, "not ok - IPC Fatal Error\n", "got 'not ok' on stdout");
    like($err, qr/IPC Fatal Error: foo/, "Got error");
};

done_testing;
