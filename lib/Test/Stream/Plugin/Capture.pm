package Test::Stream::Plugin::Capture;
use strict;
use warnings;

use Test::Stream::Util qw/try/;
use Carp qw/croak/;

use Test::Stream::Exporter;
default_exports qw/capture/;
no Test::Stream::Exporter;

sub capture(&) {
    my $code = shift;

    my ($err, $out) = ("", "");

    # Localize in case of nesting.
    local *ORIG_OUT;
    local *ORIG_ERR;

    open(*ORIG_OUT, ">&STDOUT" ) || die "Can't dup STDOUT: $!";
    open(*ORIG_ERR, ">&STDERR" ) || die "Can't dup STDERR: $!";

    my ($ok, $e) = try {
        close(STDOUT) || die "Failed to close STDOUT: $!";
        close(STDERR) || die "Failed to close STDERR: $!";
        open(STDOUT, '>', \$out) || die "Failed to open a temporary STDOUT: $!";
        open(STDERR, '>', \$err) || die "Failed to open a temporary STDERR: $!";

        $code->();
    };
    close(STDOUT) || die "Failed to close temporary STDOUT: $!";
    close(STDERR) || die "Failed to close temporary STDERR: $!";
    open(STDOUT, '>&ORIG_OUT') || die "Could not re-open original STDOUT: $!";
    open(STDERR, '>&ORIG_ERR') || die "Could not re-open original STDERR: $!";

    die $e unless $ok;

    return {
        STDOUT => $out,
        STDERR => $err,
    };
}

1;
