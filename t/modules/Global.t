use strict;
use warnings;

use Test2::Global;

my ($LOADED, $INIT, $POST_LOAD);
BEGIN {
    $INIT   = Test2::Global->init_done;
    $LOADED = Test2::Global->loaded;
    Test2::Global->loaded(1);
    $POST_LOAD = Test2::Global->loaded;
};

use Test2::IPC;
use Test2::Tester;
use Test2::Util qw/get_tid/;
my $CLASS = 'Test2::Global';

ok(!$LOADED, "Was not loaded right away");
ok(!$INIT, "Init was not done right away");
ok($POST_LOAD, "We loaded it");

# Note: This is a check that stuff happens in an END block.
{
    {
        package FOLLOW;

        sub DESTROY {
            return if $_[0]->{fixed};
            print "not ok - Did not run end ($_[0]->{name})!";
            $? = 255;
            exit 255;
        }
    }

    our $kill1 = bless {fixed => 0, name => "Custom Hook"}, 'FOLLOW';
    Test2::Global->add_hook(
        sub {
            print "# Running END hook\n";
            $kill1->{fixed} = 1;
        }
    );

    our $kill2 = bless {fixed => 0, name => "set exit"}, 'FOLLOW';
    my $old = Test2::Global::Instance->can('set_exit');
    no warnings 'redefine';
    *Test2::Global::Instance::set_exit = sub {
        $kill2->{fixed} = 1;
        print "# Running set_exit\n";
        $old->(@_);
    };
}

ok($CLASS->init_done, "init is done.");
ok($CLASS->loaded, "Test2 is finished loading");

is($CLASS->pid, $$, "got pid");
is($CLASS->tid, get_tid(), "got tid");

ok($CLASS->stack, 'got stack');
is($CLASS->stack, $CLASS->stack, "always get the same stack");

ok($CLASS->ipc, 'got ipc');
is($CLASS->ipc, $CLASS->ipc, "always get the same IPC");

ok($CLASS->formatter, "Got a formatter");
is($CLASS->formatter, $CLASS->formatter, "always get the same Formatter (class name)");

ok($CLASS->hooks >= 1, "We added a hook, make sure there is at least 1");

my $ran = 0;
$CLASS->post_load(sub { $ran++ });
is($ran, 1, "ran the post-load");
ok($CLASS->post_loads >= 1, "we have at least 1 post-load");

like(
    exception { $CLASS->set_formatter() },
    qr/No formatter specified/,
    "set_formatter requires an argument"
);

like(
    exception { $CLASS->set_formatter('fake') },
    qr/Global Formatter already set/,
    "set_formatter doesn't work after initialization",
);

ok(!$CLASS->no_wait, "no_wait is not set");
$CLASS->no_wait(1);
ok($CLASS->no_wait, "no_wait is set");
$CLASS->no_wait(undef);
ok(!$CLASS->no_wait, "no_wait is not set");

done_testing;
