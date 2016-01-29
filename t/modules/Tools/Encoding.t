use Test2::Bundle::Extended -target => 'Test2::Tools::Encoding';

use File::Temp qw/tempfile/;

{
    package Temp;
    use Test2::Tools::Encoding;

    main::imported_ok(qw/set_encoding/);
}

my $warnings;
intercept {
    $warnings = warns {
        use utf8;

        my ($fh, $name) = tempfile();

        Test2::API::test2_stack->top->format(
            Test2::Formatter::TAP->new(
                handles => [$fh, $fh, $fh],
            ),
        );

        set_encoding('utf8');
        ok(1, '†');
    };
};

ok(!$warnings, "set_encoding worked");

my $exception;
intercept {
    $exception = dies {
        set_encoding('utf8');
    };
};

like(
    $exception,
    qr/Unable to set encoding on formatter '<undef>'/,
    "Cannot set encoding without a formatter"
);

done_testing;
