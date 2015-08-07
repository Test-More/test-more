use Test::Stream '-Tester';

# Module Installed
##################
my $events = intercept { load_plugin SkipWithout => ['Scalar::Util'] };
is(@$events, 0, "No events, module is present");

events_are(
    intercept { local @INC; load_plugin SkipWithout => ['Some::Fake::Module'] },
    events {
        event Plan => {
            max => 0,
            directive => 'SKIP',
            reason => "Module 'Some::Fake::Module' is not installed",
        };
        end_events;
    },
    "Skipped, module is not installed"
);

# Perl Version
##############
$events = intercept { load_plugin SkipWithout => ['v5.00'] };
is(@$events, 0, "Minimum perl version met");

events_are(
    intercept { load_plugin SkipWithout => ['v100.00'] },
    events {
        event Plan => {
            max => 0,
            directive => 'SKIP',
            reason => "Perl v100.0.0 required",
        };
        end_events;
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

events_are(
    intercept { load_plugin SkipWithout => [{Foo => '2.00'}] },
    events {
        event Plan => {
            max => 0,
            directive => 'SKIP',
            reason => qr/Foo version/,
        };
        end_events;
    },
    "Did not meet minimum module version"
);

done_testing;
