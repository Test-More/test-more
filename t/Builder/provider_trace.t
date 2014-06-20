use strict;
use warnings;

sub tester {
    Test::Builder->trace_anointed();
}
sub provider {
    Test::Builder->trace_provider();
}

BEGIN {
    $INC{'XXX/Provider.pm'} = __FILE__;
    $INC{'XXX/Tester.pm'}   = __FILE__;
}

# line 1000
{
    package XXX::Provider;
    use Test::Builder::Provider;

    BEGIN {
        provide explode => sub {
            exploded();
        };
    }

    sub exploded { overkill() }

# line 1500
    sub overkill {
        return {
            provider => main::provider(),
            tester   => main::tester(),
        };
    }
}

# line 2000
package XXX::Tester;
use XXX::Provider;
use Test::Builder::Provider;
use Data::Dumper;
use Test::More;

provides 'explodable';
# line 2100
sub explodable    { explode() };
# line 2200
sub explodadouble { explode() };

# line 2300
is_deeply( # The call will trace to here.
    explodable(),
    {
        provider => ['XXX::Provider', __FILE__, 1502],
        tester   => ['XXX::Tester',   __FILE__, 2300],
    },
    "Properly traced call to tool provided by this package"
);

# line 2400
is_deeply(
    explodadouble(),
    {
        provider => ['XXX::Provider', __FILE__, 1502],
        tester   => ['XXX::Tester',   __FILE__, 2200],
    },
    "Eploadadouble is not 'provided' so the trace goes to the tool call within"
);

# line 2500
is_deeply( # The call will trace to here
    explode(),
    {
        provider => ['XXX::Provider', __FILE__, 1502],
        tester   => ['XXX::Tester',   __FILE__, 2500],
    },
    "Properly traced call to tool provided by external package"
);

done_testing;
