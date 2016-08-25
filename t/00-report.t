use strict;
use warnings;

my $exit = 0;
END{ $? = $exit }

use File::Spec;

my ($stderr, $stdout);
BEGIN {
    $exit = 0;
    END{ $? = $exit }
    print STDOUT "ok 1\n";
    print STDOUT "1..1\n";

    open($stdout, '>&', *STDOUT) or die "Could not clone STDOUT";
    open($stderr, '>&', *STDERR) or die "Could not clone STDERR";

    close(STDOUT) or die "Could not close STDOUT";
    unless(close(STDERR)) {
        print $stderr "Could not close STDERR\n";
        $exit = 255;
        exit $exit;
    }

    open(STDOUT, '>', File::Spec->devnull);
    open(STDERR, '>', File::Spec->devnull);
}

use Test2::Util qw/CAN_FORK CAN_REALLY_FORK CAN_THREAD/;
use Test2::API;

sub diag {
    print $stderr "\n" unless @_;
    print $stderr "# $_\n" for @_;
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

END{ $? = $exit }
