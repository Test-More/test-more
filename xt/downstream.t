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

ok(run_string(<<"EOT"), "Installed downstream modules with no issues") || exit 1;
perlbrew exec --with TestMore$$ cpanm `cat xt/downstream_dists.list`
EOT


if (-e 'xt/downstream_dists.list.known_broken') {
    local $TODO = "These are known to be broken";
    ok(run_string(<<"    EOT"), "Known broken dists");
    perlbrew exec --with TestMore$$ cpanm `cat xt/downstream_dists.list.known_broken`
    EOT
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
