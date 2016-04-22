use strict;
use warnings;

use Test2::Util qw/CAN_FORK CAN_REALLY_FORK CAN_THREAD/;

sub diag {
    print STDERR "\n" unless @_;
    print STDERR "# $_\n" for @_;
}

diag;
diag "DIAGNOSTICS INFO IN CASE OF FAILURE:";
diag;
diag "Perl: $]";

diag;
diag "CAPABILITIES:";
diag 'CAN_FORK         ' . (CAN_FORK        ? 'Yes' : 'No');
diag 'CAN_REALLY_FORK  ' . (CAN_REALLY_FORK ? 'Yes' : 'No');
diag 'CAN_THREAD       ' . (CAN_THREAD      ? 'Yes' : 'No');

diag;
diag "DEPENDENCIES:";

my @depends = sort qw{
    Carp
    File::Spec
    File::Temp
    PerlIO
    Scalar::Util
    Storable
    Test2
    overload
    threads
    utf8
};

my %deps;
my $len = 0;
for my $dep (@depends) {
    my $l = length($dep);
    $len = $l if $l > $len;
    $deps{$dep} = eval "require $dep; $dep->VERSION" || "N/A";
}

diag sprintf("%-${len}s  %s", $_, $deps{$_}) for @depends;

require Test2::API::Breakage;
my @warn = Test2::API::Breakage->report(1);

diag;
if (@warn) {
    diag "You have the following module versions known to have issues with Test2:";
    diag "$_" for @warn;
}

print "ok 1\n";
print "1..1\n";
