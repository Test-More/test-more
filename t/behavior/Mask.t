use Test::Stream -V1, Spec, skip_without => {'Trace::Mask' => '0.000002'}, Compare => '*';

use Trace::Mask::Reference qw/trace/;
use Test::Stream::Util qw/try protect/;

my $trace; my $line;
my ($ok, $error) = try {
    $trace = trace(); $line = __LINE__;
};
ok($ok, "no error");
like(
    $trace,
    [ [ [__PACKAGE__, __FILE__, $line, 'Trace::Mask::Reference::trace'] ], DNE() ],
    "try frames are hidden"
);

protect {
    $trace = trace(); $line = __LINE__;
};
like(
    $trace,
    [ [ [__PACKAGE__, __FILE__, $line, 'Trace::Mask::Reference::trace'] ], DNE() ],
    "protect frames are hidden"
);

my $wrap_line;
sub wrap {
    my ($ok, $error) = try {
        $trace = trace(); $line = __LINE__;
    };
    ok($ok, "no error");
    like(
        $trace,
        [
            [ [__PACKAGE__, __FILE__, $line, 'Trace::Mask::Reference::trace'] ],
            [ [__PACKAGE__, __FILE__, $wrap_line, 'main::wrap'] ],
            DNE()
        ],
        "try frames are hidden (wrapped)"
    );

    protect {
        $trace = trace(); $line = __LINE__;
    };
    like(
        $trace,
        [
            [ [__PACKAGE__, __FILE__, $line, 'Trace::Mask::Reference::trace'] ],
            [ [__PACKAGE__, __FILE__, $wrap_line, 'main::wrap'] ],
            DNE()
        ],
        "protect frames are hidden (wrapped)"
    );
}
$wrap_line = __LINE__ + 1;
wrap();

# Test protect

my $done_testing_line;
describe builder_1 => sub {
    my $trace_1 = trace(); my $trace_1_line = __LINE__;

    my ($outer_around, $outer_around_line);
    around_each outer_around => sub {
        $outer_around = trace(); $outer_around_line = __LINE__;
        $_[0]->();
    };

    describe builder_2 => sub {
        my $trace_2 = trace(); my $trace_2_line = __LINE__;

        my ($trace_before, $trace_before_line);
        my ($trace_other,  $trace_other_line);
        my ($trace_around, $trace_around_line);

        before_each before => sub {
            $trace_before = trace(); $trace_before_line = __LINE__;
        };

        around_each around => sub {
            $trace_around = trace(); $trace_around_line = __LINE__;
            $_[0]->();
        };

        before_each other => sub {
            $trace_other = trace(); $trace_other_line = __LINE__;
        };

        tests test_deep => sub {
            ok(1);
            my $trace_test = trace(); my $trace_test_line = __LINE__;

            like(
                $trace_1,
                [ [ [__PACKAGE__, __FILE__, $trace_1_line, 'Trace::Mask::Reference::trace'] ], DNE() ],
                "call to trace"
            );

            like(
                $trace_2,
                [ [ [__PACKAGE__, __FILE__, $trace_2_line, 'Trace::Mask::Reference::trace'] ], DNE() ],
                "call to trace"
            );

            like(
                $outer_around,
                [
                    [ [__PACKAGE__, __FILE__, $outer_around_line, 'Trace::Mask::Reference::trace'] ],
                    [ [__PACKAGE__, __FILE__, $done_testing_line, qr/done_testing$/] ],
                    DNE(),
                ],
                "call to trace and done_testing"
            );

            like(
                $trace_before,
                [
                    [ [__PACKAGE__, __FILE__, $trace_before_line, 'Trace::Mask::Reference::trace'] ],
                    [ [__PACKAGE__, __FILE__, $outer_around_line + 1, 'CONTINUE'] ],
                    [ [__PACKAGE__, __FILE__, $done_testing_line, qr/done_testing$/] ],
                    DNE(),
                ],
                "call to trace, outer_around, and done_testing"
            );

            like(
                $trace_around,
                [
                    [ [__PACKAGE__, __FILE__, $trace_around_line, 'Trace::Mask::Reference::trace'] ],
                    [ [__PACKAGE__, __FILE__, $outer_around_line + 1, 'CONTINUE'] ],
                    [ [__PACKAGE__, __FILE__, $done_testing_line, qr/done_testing$/] ],
                    DNE(),
                ],
                "call to trace, outer_around, and done_testing"
            );

            like(
                $trace_other,
                [
                    [ [__PACKAGE__, __FILE__, $trace_other_line, 'Trace::Mask::Reference::trace'] ],
                    [ [__PACKAGE__, __FILE__, $trace_around_line + 1, 'CONTINUE'] ],
                    [ [__PACKAGE__, __FILE__, $outer_around_line + 1, 'CONTINUE'] ],
                    [ [__PACKAGE__, __FILE__, $done_testing_line, qr/done_testing$/] ],
                    DNE(),
                ],
                "call to trace, inner around, outer_around, and done_testing"
            );

            like(
                $trace_test,
                [
                    [ [__PACKAGE__, __FILE__, $trace_test_line, 'Trace::Mask::Reference::trace'] ],
                    [ [__PACKAGE__, __FILE__, $trace_around_line + 1, 'CONTINUE'] ],
                    [ [__PACKAGE__, __FILE__, $outer_around_line + 1, 'CONTINUE'] ],
                    [ [__PACKAGE__, __FILE__, $done_testing_line, qr/done_testing$/] ],
                    DNE(),
                ],
                "call to trace, inner around, outer_around, and done_testing"
            );
        };
    };
};

BEGIN { $done_testing_line = __LINE__ + 1 };
done_testing;
