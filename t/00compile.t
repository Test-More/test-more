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

chdir "..";
my $manifest = "MANIFEST";
open(my $manifest_fh, "<", $manifest) or die "Can't open $manifest: $!";
my @modules = map  { m{^lib/(\S+)}; $1 }
              grep { m{^lib/Test/\S*\.pm} }
              grep { !m{/t/} } <$manifest_fh>;

chomp @modules;
close $manifest_fh;

chdir 'lib';
foreach my $file (@modules) {
    # Make sure we look at the local files and do not reload them if
    # they're already loaded.  This avoids recompilation warnings.
    local @INC = @INC;
    unshift @INC, ".";
    ok eval { require($file); 1 }, "$file loaded" or diag "require $file failed.\n$@";
}

done_testing;
