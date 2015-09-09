use Test::Stream -V1, Capture;

imported_ok('capture');

is(
    capture {
        print STDERR "First STDERR\n";
        print STDOUT "First STDOUT\n";
        print STDERR "Second STDERR\n";
        print STDOUT "Second STDOUT\n";
    },
    {
        STDOUT => "First STDOUT\nSecond STDOUT\n",
        STDERR => "First STDERR\nSecond STDERR\n",
    },
    "Captured stdout and stderr"
);

is(
    capture {
        print STDERR "First STDERR\n";
        print STDOUT "First STDOUT\n";

        is(
            capture {
                print STDERR "First STDERR\n";
                print STDOUT "First STDOUT\n";
                print STDERR "Second STDERR\n";
                print STDOUT "Second STDOUT\n";
            },
            {
                STDOUT => "First STDOUT\nSecond STDOUT\n",
                STDERR => "First STDERR\nSecond STDERR\n",
            },
            "Captured stdout and stderr (nested)"
        );

        print STDERR "Second STDERR\n";
        print STDOUT "Second STDOUT\n";
    },
    {
        STDOUT => "First STDOUT\nSecond STDOUT\n",
        STDERR => "First STDERR\nSecond STDERR\n",
    },
    "Captured stdout and stderr (wrapper)"
);

like(
    dies { capture { die "tribbles" } },
    qr/tribbles/,
    "Error inside is propogated"
);

done_testing;
