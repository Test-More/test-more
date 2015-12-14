use strict;
use warnings;

use Test2::IPC;

my @drivers;
BEGIN { @drivers = Test2::IPC->drivers };

use Test2::Tester;
use Test2 qw/context/;
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
    ['Test2::IPC::Files'],
    "Got default driver"
);

require Test2::IPC::Files;
Test2::IPC::Files->import();
Test2::IPC::Files->import();
Test2::IPC::Files->import();

Test2::IPC->register_drivers(
    'Test2::IPC::Files',
    'Test2::IPC::Files',
    'Test2::IPC::Files',
);

is_deeply(
    [Test2::IPC->drivers],
    ['Test2::IPC::Files'],
    "Driver not added multiple times"
);

tests init_drivers => sub {
    ok( !exception { Test2::IPC->new }, "Found working driver" );

    no warnings 'redefine';
    local *Test2::IPC::Files::is_viable = sub { 0 };
    use warnings;

    like(
        exception { Test2::IPC->new },
        qr/Could not find a viable IPC driver! Aborting/,
        "No viable drivers"
    );

    no warnings 'redefine';
    local *Test2::IPC::Files::is_viable = sub { undef };
    use warnings;
    like(
        exception { Test2::IPC->new },
        qr/Could not find a viable IPC driver! Aborting/,
        "No viable drivers"
    );
};

tests polling => sub {
    my $inst = Test2::Global->_internal_use_only_private_instance;

    ok(!Test2::IPC->polling_enabled, "no polling yet");
    ok(!@{$inst->context_init_callbacks}, "no context init callbacks yet");

    Test2::IPC->enable_polling;

    ok(1 == @{$inst->context_init_callbacks}, "added 1 callback");
    ok(Test2::IPC->polling_enabled, "polling enabled");

    Test2::IPC->enable_polling;

    ok(1 == @{$inst->context_init_callbacks}, "Did not add callback twice");
};

for my $meth (qw/send cull add_hub drop_hub waiting is_viable/) {
    my $one = Test2::IPC->new;
    like(
        exception { $one->$meth },
        qr/'\Q$one\E' did not define the required method '$meth'/,
        "Require override of method $meth"
    );
}

tests abort => sub {
    my $one = Test2::IPC->new(no_fatal => 1);
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
