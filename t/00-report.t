use Test::Stream -V1;

use Test::Stream::Table qw/table/;

diag "\nDIAGNOSTICS INFO IN CASE OF FAILURE:\n";
diag(join "\n", table(rows => [[ 'perl', $] ]]));

{
    my @depends = qw{
        B Carp File::Spec File::Temp List::Util PerlIO Scalar::Util
        Scalar::Util Storable Test::Harness overload utf8
    };

    my @rows;
    for my $mod (sort @depends) {
        my $installed = eval "require $mod; $mod->VERSION";
        push @rows => [ $mod, $installed || "N/A" ];
    }

    my @table = table(
        header => [ 'DEPENDENCY', 'VERSION' ],
        rows => \@rows,
    );

    diag(join "\n", @table);
}

{
    my @options = qw{
        Sub::Name Sub::Util Term::ReadKey Unicode::GCString Unicode::LineBreak
    };

    my @rows;
    for my $mod (sort @options) {
        my $installed = eval "require $mod; $mod->VERSION";
        push @rows => [ $mod, $installed || "N/A" ];
    }

    my @table = table(
        header => [ 'OPTIONAL', 'VERSION' ],
        rows => \@rows,
    );

    diag(join "\n", @table);
}

pass;
done_testing;
