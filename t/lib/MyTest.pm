use strict;
use warnings;

package MyTest;

use Test::Builder;

my $Test = Test::Builder->new;

sub ok
{
    local $Test::Builder::Level = $Test::Builder::Level + 1;
	$Test->ok(@_);
}

1;
