#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    unless ( $ENV{DOWNSTREAM_TESTS} ) {
        print "1..0 # Enable with DOWNSTREAM_TESTS.\n";
        exit 0;
    }
}

use Test::More;

my $lib = "5.20.3_no_thr\@TestMore$$";

ok(run_string(<<"EOT"), "Installed a fresh perlbrew") || exit 1;
perlbrew lib create $lib
EOT

ok(run_string(<<"EOT"), "Installed cpanm") || exit 1;
perlbrew exec --with $lib cpan App::cpanminus
EOT

my ($tarball, $bad) = grep { -f $_ } glob("*.tar.gz");
ok(!$bad, "Only 1 Test-Simple tarball")      || exit 1;
ok($tarball, "Found the tarball ($tarball)") || exit 1;
ok(run_string(<<"EOT"), "Installed Test::More ($tarball)") || exit 1;
perlbrew exec --with $lib cpanm $tarball
EOT

ok(run_string(<<"EOT"), "Installed LWP") || exit 1;
perlbrew exec --with $lib cpanm LWP
EOT

ok(run_string(<<"EOT"), "Installed Devel::Declare") || exit 1;
perlbrew exec --with $lib cpanm Devel::Declare
EOT

for my $i (qw/Suite Harness/) {
    my $ok = 0;
    for (1 .. 2) {
        $ok = run_string(<<"        EOT");
        perlbrew exec --with $lib cpanm --installdeps --dev Test2::$i
        EOT

        $ok &&= run_string(<<"        EOT");
        perlbrew exec --with $lib cpanm --dev --reinstall Test2::$i
        EOT

        last if $ok;
        diag "'Test2::$i' did not install properly, trying 1 more time.";
    }
    ok($ok, "Installed Test2::$i") || exit 1;
}

ok(run_string(<<"EOT"), "Installed Archive::Zip") || exit 1;
perlbrew exec --with $lib cpanm -n -f Archive::Zip
EOT

ok(run_string(<<"EOT"), "Installed Net::SSLeay") || exit 1;
perlbrew exec --with $lib cpanm -n -f IO::Socket::SSL Net::SSLeay
EOT

my @BAD;
open(my $list, '<', 'xt/downstream_dists.list') || die "Could not open downstream list";
while(my $name = <$list>) {
    chomp($name);
    my $ok = 0;
    for (1 .. 2) {
        $ok = run_string("perlbrew exec --with $lib cpanm --reinstall $name");
        last if $ok;
        diag "'$name' did not install properly, trying 1 more time.";
    }

    ok($ok, "Installed downstream module '$name'") || push @BAD => $name;
}
close($list);

TODO: {
    local $TODO = "known to be broken";

    open($list, '<', 'xt/downstream_dists.list.known_broken') || die "Could not open downstream list";
    while(my $name = <$list>) {
        chomp($name);
        my $ok = 0;
        for (1 .. 2) {
            $ok = run_string("perlbrew exec --with $lib cpanm --reinstall $name");
            last if $ok;
            diag "'$name' did not install properly, trying 1 more time.";
        }

        ok($ok, "Installed downstream module '$name'");
    }
    close($list);
}

ok(run_string(<<"EOT"), "Cleanup up the perlbrew") unless @BAD;
perlbrew lib delete $lib
EOT

sub run_string {
    my $exec = shift;
    print "Command: $exec\n";
    local %ENV = %ENV;

    delete $ENV{$_} for (
        'DOWNSTREAM_TESTS',
        'HARNESS_ACTIVE',
        'HARNESS_IS_VERBOSE',
        'HARNESS_VERSION',
        'OLDPWD',
        'PERL5LIB',
        'TAP_VERSION',
        'TEST_VERBOSE',
    );

    my $pid = fork;
    die "Failed to fork!" unless defined $pid;
    exec $exec unless $pid;

    die "Something went wrong!" unless $pid;

    my $got = waitpid($pid, 0);
    my $out = !$?;
    die "waitpid oddity, got $got, expected $pid" unless $got == $pid;
    return $out;
}

done_testing;

if (@BAD) {
    print "Bad:\n",join( "\n", @BAD ), "\n";
}
