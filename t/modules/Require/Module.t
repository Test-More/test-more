use Test2::Bundle::Extended -target => 'Test2::Require::Module';
BEGIN { require 't/tools.pl' }

is($CLASS->skip('Scalar::Util'), undef, "will not skip, module installed");
is($CLASS->skip('Scalar::Util', 0.5), undef, "will not skip, module at sufficient version");

is(
    $CLASS->skip('Test2', '99999'),
    "Need 'Test2' version 99999, have 0.000016.",
    "Skip, insufficient version"
);

is(
    $CLASS->skip('Some::Fake::Module'),
    "Module 'Some::Fake::Module' is not installed",
    "Skip, not installed"
);

done_testing;
