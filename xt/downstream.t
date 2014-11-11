#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    unless ( $ENV{DOWNSTREAM_TESTS} ) {
        print "1..0 # Skip many perls have broken threads.  Enable with AUTHOR_TESTING.\n";
        exit 0;
    }
}

use Test::More;

ok(run_string(<<"EOT"), "Installed a fresh perlbrew") || exit 1;
perlbrew uninstall TestMore$$ 1>/dev/null 2>/dev/null || true
perlbrew install --thread --notest -j9 --as TestMore$$ perl-5.20.1
EOT

ok(run_string(<<"EOT"), "Installed Test::More") || exit 1;
perlbrew exec --with TestMore$$ cpan .
EOT

ok(run_string(<<"EOT"), "Installed cpanm") || exit 1;
perlbrew exec --with TestMore$$ cpan App::cpanminus
EOT

open(my $list, '<', 'xt/downstream_dists.list') || die "Could not open downstream list";
while(my $name = <$list>) {
    chomp($name);
    my $ok = 0;
    for (1 .. 2) {
        $ok = run_string("perlbrew exec --with TestMore$$ -- cpanm $name");
        last if $ok;
        diag "'$name' did not install properly, trying 1 more time.";
    }

    ok($ok, "Installed downstream module '$name'") || exit 1;
}
close($list);

TODO: {
    local $TODO = "known to be broken";

    open($list, '<', 'xt/downstream_dists.list.known_broken') || die "Could not open downstream list";
    while(my $name = <$list>) {
        chomp($name);
        my $ok = 0;
        for (1 .. 2) {
            $ok = run_string("perlbrew exec --with TestMore$$ cpanm $name");
            last if $ok;
            diag "'$name' did not install properly, trying 1 more time.";
        }

        ok($ok, "Installed downstream module '$name'");
    }
    close($list);
}

ok(run_string(<<"EOT"), "Cleanup up the perlbrew");
perlbrew uninstall TestMore$$
EOT

sub run_string {
    my $exec = shift;
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

    return !system($exec);
}

done_testing;
