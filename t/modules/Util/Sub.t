use Test2::Bundle::Extended;
BEGIN { require 't/tools.pl' }

use Test2::Util::Sub qw{
    sub_info
    sub_name
};

imported_ok qw{
    sub_info
    sub_name
};

sub named { 'named' }
*unnamed = sub { 'unnamed' };
like(sub_name(\&named), qr/named$/, "got sub name (named)");
like(sub_name(\&unnamed), qr/__ANON__$/, "got sub name (anon)");

like(
    dies { sub_name() },
    qr/sub_name requires a coderef as its only argument/,
    "Need an arg"
);

like(
    dies { sub_name('xxx') },
    qr/sub_name requires a coderef as its only argument/,
    "Need a ref"
);

like(
    dies { sub_name({}) },
    qr/sub_name requires a coderef as its only argument/,
    "Need a code ref"
);

no warnings 'once';
sub empty_named { };   my $empty_named = __LINE__;
*empty_anon = sub { }; my $empty_anon  = __LINE__;

sub one_line_named { 1 };   my $one_line_named = __LINE__;
*one_line_anon = sub { 1 }; my $one_line_anon  = __LINE__;

my $multi_line_named_start = __LINE__ + 1;
sub multi_line_named {
    my $x = 1;
    $x++;
    return $x;
}
my $multi_line_named_end = __LINE__ - 1;
my $multi_line_anon_start = __LINE__ + 1;
*multi_line_anon = sub {
    my $x = 1;
    $x++;
    return $x;
};
my $multi_line_anon_end = __LINE__ - 1;
use warnings 'once';

like(
    sub_info(\&empty_named),
    {
        name       => qr/empty_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&empty_named),
        cobj       => T(),
        start_line => in_set(undef, $empty_named),
        end_line   => in_set(undef, $empty_named),
        lines      => in_set([], [$empty_named, $empty_named]),
        all_lines  => in_set([], [$empty_named]),
    },
    "Got expected results for empty named sub"
);

like(
    sub_info(\&empty_anon),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&empty_anon),
        cobj       => T(),
        start_line => in_set(undef, $empty_anon),
        end_line   => in_set(undef, $empty_anon),
        lines      => in_set([], [$empty_anon, $empty_anon]),
        all_lines  => in_set([], [$empty_anon]),
    },
    "Got expected results for empty anon sub"
);

like(
    sub_info(\&one_line_named),
    {
        name       => qr/one_line_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&one_line_named),
        cobj       => T(),
        start_line => $one_line_named,
        end_line   => $one_line_named,
        lines      => [$one_line_named, $one_line_named],
        all_lines  => [$one_line_named],
    },
    "Got expected results for one line named sub"
);

like(
    sub_info(\&one_line_anon),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&one_line_anon),
        cobj       => T(),
        start_line => $one_line_anon,
        end_line   => $one_line_anon,
        lines      => [$one_line_anon, $one_line_anon],
        all_lines  => [$one_line_anon],
    },
    "Got expected results for one line anon sub"
);

like(
    sub_info(\&multi_line_named),
    {
        name       => qr/multi_line_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_named),
        cobj       => T(),
        start_line => $multi_line_named_start,
        end_line   => $multi_line_named_end,
        lines      => [$multi_line_named_start, $multi_line_named_end],
        all_lines  => [$multi_line_named_start + 1, $multi_line_named_start + 2, $multi_line_named_end - 1],
    },
    "Got expected results for multi-line named sub"
);

like(
    sub_info(\&multi_line_anon),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_anon),
        cobj       => T(),
        start_line => $multi_line_anon_start,
        end_line   => $multi_line_anon_end,
        lines      => [$multi_line_anon_start, $multi_line_anon_end],
        all_lines  => [$multi_line_anon_start + 1, $multi_line_anon_start + 2, $multi_line_anon_end - 1],
    },
    "Got expected results for multi-line anon sub"
);

like(
    sub_info(\&multi_line_named, 1, 1000),
    {
        name       => qr/multi_line_named$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_named),
        cobj       => T(),
        start_line => 1,
        end_line   => 1000,
        lines      => [1, 1000],
        all_lines  => [1, $multi_line_named_start + 1, $multi_line_named_start + 2, $multi_line_named_end - 1, 1000],
    },
    "Got expected results for multi-line named sub (custom lines)"
);

like(
    sub_info(\&multi_line_anon, 1000, 1),
    {
        name       => qr/__ANON__$/,
        package    => __PACKAGE__,
        file       => __FILE__,
        ref        => exact_ref(\&multi_line_anon),
        cobj       => T(),
        start_line => 1,
        end_line   => 1000,
        lines      => [1, 1000],
        all_lines  => [1, $multi_line_anon_start + 1, $multi_line_anon_start + 2, $multi_line_anon_end - 1, 1000],
    },
    "Got expected results for multi-line anon sub (custom lines)"
);

done_testing;
