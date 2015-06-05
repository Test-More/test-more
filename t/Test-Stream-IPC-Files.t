use strict;
use warnings;

use Test::More;
use Test::Stream::Util qw/get_tid USE_THREADS/;

require Test::Stream::IPC::Files;
ok(my $ipc = Test::Stream::IPC::Files->new, "Created an IPC instance");
isa_ok($ipc, 'Test::Stream::IPC::Files');
isa_ok($ipc, 'Test::Stream::IPC');

can_ok($ipc, qw/tempdir event_id tid pid/);

ok(-d $ipc->tempdir, "created temp dir");
is($ipc->pid, $$, "stored pid");
is($ipc->tid, get_tid(), "stored the tid");

my $hid = '12345';

$ipc->add_hub($hid);
ok(-f $ipc->tempdir . '/' . $hid, "wrote hub file");
if(ok(open(my $fh, '<', $ipc->tempdir . '/' . $hid), "opened hub file")) {
    my @lines = <$fh>;
    close($fh);
    is_deeply(
        \@lines,
        [ "$$\n", get_tid() . "\n" ],
        "Wrote pid and tid to hub file"
    );
}

{
    package Foo;
    use Test::Stream::Event;
}

$ipc->send($hid, bless({ foo => 1 }, 'Foo'));
$ipc->send($hid, bless({ bar => 1 }, 'Foo'));

opendir(my $dh, $ipc->tempdir) || die "Could not open tempdir: !?";
my @files = grep { $_ !~ m/^\.+$/ && $_ ne $hid } readdir($dh);
closedir($dh);
is(@files, 2, "2 files added to the IPC directory");

my @events = $ipc->cull($hid);
is_deeply(
    \@events,
    [{ foo => 1 }, { bar => 1 }],
    "Culled both events"
);

opendir($dh, $ipc->tempdir) || die "Could not open tempdir: !?";
@files = grep { $_ !~ m/^\.+$/ && $_ ne $hid } readdir($dh);
closedir($dh);
is(@files, 0, "All files collected");

$ipc->drop_hub($hid);
ok(!-f $ipc->tempdir . '/' . $hid, "removed hub file");

my $tmpdir = $ipc->tempdir;
ok(-d $tmpdir, "still have temp dir");
$ipc = undef;
ok(!-d $tmpdir, "cleaned up temp dir");

# TODO: Test failure conditions
# TODO: Test intentionally leaving the directory and events in place.

done_testing;
