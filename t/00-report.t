use strict;
use warnings;

BEGIN { require "t/tools.pl" };
use Data::Dumper;

use Test2::Util qw/CAN_FORK CAN_REALLY_FORK CAN_THREAD/;

diag "\nDIAGNOSTICS INFO IN CASE OF FAILURE:\n";
diag "\nPerl: $]";

diag "\nCAPABILITIES:";
diag 'CAN_FORK         ' . (CAN_FORK        ? 'Yes' : 'No');
diag 'CAN_REALLY_FORK  ' . (CAN_REALLY_FORK ? 'Yes' : 'No');
diag 'CAN_THREAD       ' . (CAN_THREAD      ? 'Yes' : 'No');

diag "\nDEPENDENCIES:";

my @depends = sort qw{
    Carp File::Spec File::Temp PerlIO
    Scalar::Util Storable overload utf8
    threads
};

my %deps;
my $len = 0;
for my $dep (@depends) {
    my $l = length($dep);
    $len = $l if $l > $len;
    $deps{$dep} = eval "require $dep; $dep->VERSION" || "N/A";
}

diag sprintf("%-${len}s  %s", $_, $deps{$_}) for @depends;

ok(1);
done_testing;
