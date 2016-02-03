use Test2::Bundle::Extended;
use Test2::Tools::Spec;
use Trace::Mask::Carp qw/longmess/;
use Test2::Workflow qw/workflow_run/;
use Test2::Tools::Grab;

my ($trace1, $trace2, $trace3);
my ($line1,  $line2,  $line3);
my ($nested_line, $outer_line);

my ($nl_line, $nae_line, $rae_line, $naa_line) = (1, 1, 1, 1);

my $spec1 = describe 'outer' => sub {
    around_all 'root_around_all' => sub {
        $naa_line = __LINE__ + 1;
        $_[0]->();
    };

    around_each 'root_around_each' => sub {
        $nae_line = __LINE__ + 1;
        $_[0]->();
    };

    case root_x => sub { note 'root case x' };

    describe nested => sub {
        around_all 'nested_around_all' => sub {
            $rae_line = __LINE__ + 1;
            $_[0]->();
        };

        around_each 'nested_around_each' => sub {
            $nl_line = __LINE__ + 1;
            $_[0]->();
        };

        case nested_x => sub { note 'nested case x' };

        $trace1 = longmess('xxx'); $line1 = __LINE__;

        tests 'nested_long' => sub {
            ok(1, 'pass');
            $trace2 = longmess('yyy'); $line2 = __LINE__;
        };

        $nested_line = __LINE__ + 1;
    };

    $outer_line = __LINE__ + 1;
};

my $spec2 = describe 'outer' => sub {
    tests foo => sub {
        ok(1);
        $trace3 = longmess('zzz'); $line3 = __LINE__;
    };
};


my $grab = grab;
my $run_line_1 = __LINE__ + 1;
workflow_run(unit => $spec1);
my $run_line_2 = __LINE__ + 1;
workflow_run(unit => $spec2);
$grab->finish;

my $file = __FILE__;
like(
    [ split /\n/, $trace1 ],
    array {
        item match qr{^xxx at \Q$file\E line $line1};
        item match qr{^\s*main::nested\(.*\) called at \Q$file\E line $nested_line};
        item match qr{^\s*main::outer\(.*\) called at \Q$file\E line $outer_line};
        end;
    },
    "Got expected trace from inside describe"
);

like(
    [ split /\n/, $trace2 ],
    array {
        item match qr{^yyy at \Q$file\E line $line2};
        item match qr{^\s*main::nested_long\(.*\) called at \Q$file\E line $nl_line};
        item match qr{^\s*main::nested_around_each\(.*\) called at \Q$file\E line $nae_line};
        item match qr{^\s*main::root_around_each\(.*\) called at \Q$file\E line $rae_line};
        item match qr{^\s*main::nested_around_all\(.*\) called at \Q$file\E line $naa_line};
        item match qr{^\s*main::root_around_all};
        item match qr{^\s*Test2::Workflow::workflow_run\(.*\) called at \Q$file\E line $run_line_1};
        end;
    },
    "Got expected trace from inside well wrapped test block"
);

like(
    [ split /\n/, $trace3 ],
    array {
        item match qr{^zzz at \Q$file\E line $line3};
        item match qr{^\s*main::foo\(.*\)};
        item match qr{^\s*Test2::Workflow::workflow_run\(.*\) called at \Q$file\E line $run_line_2};
        end;
    },
    "Got expected trace from inside shallow test block"
);

done_testing;
