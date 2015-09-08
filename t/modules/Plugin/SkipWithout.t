use Test::Stream -V1, -Tester;

# Module Installed
##################
my $events = intercept { load_plugin SkipWithout => ['Scalar::Util'] };
is(@$events, 0, "No events, module is present");

like(
    intercept { local @INC; load_plugin SkipWithout => ['Some::Fake::Module'] },
    array {
        event Plan => {
            max => 0,
            directive => 'SKIP',
            reason => "Module 'Some::Fake::Module' is not installed",
        };
        end;
    },
    "Skipped, module is not installed"
);

# Perl Version
##############
$events = intercept { load_plugin SkipWithout => ['v5.00'] };
is(@$events, 0, "Minimum perl version met");

like(
    intercept { load_plugin SkipWithout => ['v100.00'] },
    array {
        event Plan => {
            max => 0,
            directive => 'SKIP',
            reason => "Perl v100.0.0 required",
        };
        end;
    },
    "Did not meet minimum perl version"
);

# Module Version
################

{
    $INC{'Foo.pm'} = 1;
    package Foo;
    our $VERSION = '1.00';
}

$events = intercept { load_plugin SkipWithout => [{Foo => '1.00'}] };
is(@$events, 0, "Minimum module version met");

like(
    intercept { load_plugin SkipWithout => [{Foo => '2.00'}] },
    array {
        event Plan => {
            max => 0,
            directive => 'SKIP',
            reason => qr/Foo version/,
        };
        end;
    },
    "Did not meet minimum module version"
);

done_testing;
