#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}
chdir 't';

use Test::More;

my $Has_Test_Pod;
BEGIN {
    $Has_Test_Pod = eval 'use Test::Pod 0.95; 1';
}

chdir "..";
my $manifest = "MANIFEST";
open(my $manifest_fh, "<", $manifest) or plan(skip_all => "Can't open $manifest: $!");
my @modules = map  { m{^lib/(\S+)}; $1 } 
              grep { m{^lib/Test/\S*\.pm} } 
              grep { !m{/t/} } <$manifest_fh>;

chomp @modules;
close $manifest_fh;

chdir 'lib';
plan tests => scalar @modules * 2;
foreach my $file (@modules) {
    # Make sure we look at the local files and do not reload them if
    # they're already loaded.  This avoids recompilation warnings.
    local @INC = @INC;
    unshift @INC, ".";
    ok eval { require($file); 1 } or diag "require $file failed.\n$@";

    SKIP: {
        skip "Test::Pod not installed", 1 unless $Has_Test_Pod;
        pod_file_ok($file);
    }
}
