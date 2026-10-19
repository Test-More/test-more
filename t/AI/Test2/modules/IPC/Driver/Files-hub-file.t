use strict;
use warnings;

# A hub file that was not fully written must be reported as such, both when
# the write fails and when drop_hub later finds the file empty, instead of
# surfacing as "A hub file can only be closed by the process that started it".

use Errno qw/ENOSPC/;

our $FAIL_CLOSE = 0;
BEGIN {
    *CORE::GLOBAL::close = sub (;*) {
        if ($FAIL_CLOSE) {
            CORE::close($_[0]);
            $! = ENOSPC;
            return 0;
        }
        return @_ ? CORE::close($_[0]) : CORE::close();
    };
}

use Test2::Tools::Tiny;
use Test2::Util qw/ipc_separator/;
use Test2::IPC::Driver::Files;

{
    no warnings 'redefine';
    *Test2::IPC::Driver::abort = sub {
        my $self = shift;
        my ($msg) = @_;
        chomp($msg);
        die "IPC abort: $msg\n";
    };
}

my $hid = join ipc_separator, qw"12345 1 1 1";

my $ipc = Test2::IPC::Driver::Files->new();

my ($added, $err);
{
    local $FAIL_CLOSE = 1;
    $added = eval { $ipc->add_hub($hid); 1 };
    $err = $@;
}
ok(!$added, "add_hub aborts when the hub file cannot be written");
like($err, qr/Could not write hub file '\Q$hid\E'/, "says the hub file could not be written");
my $enospc = do { local $! = ENOSPC; "$!" };
like($err, qr/\Q$enospc\E/, "includes the OS error");

my $hfile = $ipc->hub_file($hid);
open(my $fh, '>', $hfile) or die "Could not truncate '$hfile': $!";
close($fh) or die "Could not close '$hfile': $!";

ok(!eval { $ipc->drop_hub($hid); 1 }, "drop_hub aborts on an empty hub file");
like($@, qr/File for hub '\Q$hid\E' is empty or truncated/, "says the hub file is empty or truncated");
unlike($@, qr/can only be closed by the process/, "does not blame the wrong process");

unlink($hfile);
$ipc = undef;

done_testing;
