use strict;
use warnings;

sub trace {
    my $trace = Test::Builder->trace_test;
    return $trace;
}

BEGIN {
    $INC{'XXX/Provider.pm'} = __FILE__;
    $INC{'XXX/LegacyProvider.pm'} = __FILE__;
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

    sub overkill {
        return main::trace();
    }

    sub nestit(&) {
        my ($code) = @_;
        $code->();
        return main::trace();
    }

    sub nonest(&) {
        my ($code) = @_;
        $code->();
        return main::trace();
    }

    BEGIN {
        provide_nests qw/nestit/;

        provides qw/nonest/;
    }
}

# line 1500
{
    package XXX::LegacyProvider;
    use base 'Test::Builder::Module';

    our @EXPORT;
    BEGIN { @EXPORT = qw/do_it do_it_2 do_nestit do_nonest/ };

# line 1600
    sub do_it {
        my $builder = __PACKAGE__->builder;

        my $trace = Test::Builder->trace_test;
        return $trace;
    }

# line 1700
    sub do_it_2 {
        local $Test::Builder::Level = $Test::Builder::Level + 1;
        do_it(@_);
    }

# line 1800
    sub do_nestit(&) {
        my ($code) = @_;
        my $trace = Test::Builder->trace_test;
        # TODO: I Think this is wrong...
        local $Test::Builder::Level = $Test::Builder::Level + 3;
        $code->();
        return $trace;
    }
}

# line 2000
package XXX::Tester;
use XXX::Provider;
use XXX::LegacyProvider;
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
        report => {
            'line' => 2300,
            'package' => 'XXX::Tester',
            'provider_tool' => {package => 'XXX::Tester', name => 'explodable'},
            'anointed' => 1,
            'file' => __FILE__,
            'report' => 1,
        },
        stack => [
            {
                'transition' => 1,
                'file' => __FILE__,
                'line' => 5,
                'package' => 'main',
            },
            {
                'line' => 2100,
                'package' => 'XXX::Tester',
                'provider_tool' => {package => 'XXX::Provider', name => 'explode'},
                'anointed' => 1,
                'file' => __FILE__
            },
            {
                'provider_tool' => {package => 'XXX::Tester', name => 'explodable'},
                'file' => __FILE__,
                'anointed' => 1,
                'line' => 2300,
                'package' => 'XXX::Tester',
                'report' => 1,
            }
        ],
    },
    "Properly traced call to tool provided by this package"
);

# line 2400
is_deeply(
    explodadouble(),
    {
        report => {
            'line' => 2200,
            'package' => 'XXX::Tester',
            'file' => __FILE__,
            'provider_tool' => {package => 'XXX::Provider', name => 'explode'},
            'anointed' => 1,
            'report' => 1,
        },
        stack => [
            {
                'line' => 5,
                'package' => 'main',
                'transition' => 1,
                'file' => __FILE__,
            },
            {
                'line' => 2200,
                'package' => 'XXX::Tester',
                'file' => __FILE__,
                'provider_tool' => {package => 'XXX::Provider', name => 'explode'},
                'anointed' => 1,
                'report' => 1,
            },
            {
                'line' => 2400,
                'package' => 'XXX::Tester',
                'file' => __FILE__,
                'anointed' => 1,
            },
        ],
    },
    "Exploadadouble is not 'provided' so the trace goes to the tool call within"
);

# line 2500
is_deeply( # The call will trace to here
    explode(),
    {
        report => {
            'provider_tool' => {package => 'XXX::Provider', name => 'explode'},
            'anointed' => 1,
            'line' => 2500,
            'file' => __FILE__,
            'package' => 'XXX::Tester',
            'report' => 1,
        },
        stack => [
            {
                'line' => 5,
                'file' => __FILE__,
                'transition' => 1,
                'package' => 'main',
            },
            {
                'provider_tool' => {package => 'XXX::Provider', name => 'explode'},
                'anointed' => 1,
                'line' => 2500,
                'file' => __FILE__,
                'package' => 'XXX::Tester',
                'report' => 1,
            },
        ],
    },
    "Properly traced call to tool provided by external package"
);

# line 2600
is_deeply(
    do_it,
    {
        'report' => {
            'line' => 2600,
            'anointed' => 1,
            'package' => 'XXX::Tester',
            'file' => __FILE__,
            'report' => 1,
        },
        'stack' => [
            {
                'file' => __FILE__,
                'package' => 'XXX::LegacyProvider',
                'line' => 1603,
                'transition' => 1
            },
            {
                'line' => 2600,
                'anointed' => 1,
                'package' => 'XXX::Tester',
                'file' => __FILE__,
                'report' => 1,
            },
        ],
    },
    "Trace with legacy style provider using \$Level"
);

# line 2700
is_deeply(
    do_it_2,
    {
        'report' => {
            'line' => 2700,
            'package' => 'XXX::Tester',
            'file' => __FILE__,
            'report' => 1,
            'anointed' => 1,
            'level' => 1,
        },
        'stack' => [
            {
                'file' => __FILE__,
                'package' => 'XXX::LegacyProvider',
                'line' => 1603,
                'transition' => 1,
            },
            {
                'line' => 2700,
                'package' => 'XXX::Tester',
                'file' => __FILE__,
                'report' => 1,
                'anointed' => 1,
                'level' => 1,
            },
        ],
    },
    "Trace with legacy style provider using a deeper \$Level"
);

my @results;

# Here we simulate subtests
# line 2800
my $trace = nestit {
    push @results => explodable();
    push @results => explodadouble();
    push @results => explode();
    push @results => do_it();
    push @results => do_it_2();
}; # Report line is here

is($trace->{report}->{line}, 2806, "Nesting tool reported correct line");

is($results[0]->{report}->{line}, 2801, "Got nested line, our tool");
is($results[1]->{report}->{line}, 2200, "Nested, but tool is not 'provided' so goes up to provided");
is($results[2]->{report}->{line}, 2803, "Got nested line external tool");
is($results[3]->{report}->{line}, 2804, "Got nested line legacy tool");
is($results[4]->{report}->{line}, 2805, "Got nested line deeper legacy tool");

@results = ();
my $outer;
# line 2900
$outer = nestit {
    $trace = nestit {
        push @results => explodable();
        push @results => explodadouble();
        push @results => explode();
        push @results => do_it();
        push @results => do_it_2();
    }; # Report line is here
};

# line 2920
is($outer->{report}->{line}, 2908, "Nesting tool reported correct line");
is($trace->{report}->{line}, 2907, "Nesting tool reported correct line");

# line 2930
is($results[0]->{report}->{line}, 2902, "Got nested line, our tool");
is($results[1]->{report}->{line}, 2200, "Nested, but tool is not 'provided' so goes up to provided");
is($results[2]->{report}->{line}, 2904, "Got nested line external tool");
is($results[3]->{report}->{line}, 2905, "Got nested line legacy tool");
is($results[4]->{report}->{line}, 2906, "Got nested line deeper legacy tool");

@results = ();
# line 3000
$trace = nonest {
    push @results => explodable();
    push @results => explodadouble();
    push @results => explode();
    push @results => do_it();
    push @results => do_it_2();
}; # Report line is here

is($trace->{report}->{line}, 3006, "NoNesting tool reported correct line");

is($results[0]->{report}->{line}, 3006, "Lowest tool is nonest, so these get squashed (Which is why you use nesting)");
is($results[1]->{report}->{line}, 3006, "Lowest tool is nonest, so these get squashed (Which is why you use nesting)");
is($results[2]->{report}->{line}, 3006, "Lowest tool is nonest, so these get squashed (Which is why you use nesting)");
is($results[3]->{report}->{line}, 3006, "Lowest tool is nonest, so these get squashed(Legacy) (Which is why you use nesting)");
is($results[4]->{report}->{line}, 3006, "Lowest tool is nonest, so these get squashed(Legacy) (Which is why you use nesting)");

@results = ();

# line 3100
$trace = do_nestit {
    push @results => explodable();
    push @results => explodadouble();
    push @results => explode();
    push @results => do_it();
    push @results => do_it_2();
}; # Report line is here

is($trace->{report}->{line}, 3106, "Nesting tool reported correct line");

is($results[0]->{report}->{line}, 3101, "Got nested line, our tool");
is($results[1]->{report}->{line}, 2200, "Nested, but tool is not 'provided' so goes up to provided");
is($results[2]->{report}->{line}, 3103, "Got nested line external tool");
is($results[3]->{report}->{line}, 3104, "Got nested line legacy tool");
is($results[4]->{report}->{line}, 3105, "Got nested line deeper legacy tool");

done_testing;

