use strict;
use warnings;

use Test2::Util();
use Carp();

our @EXPORT = qw/warning warns no_warnings lives dies capture/;
use base 'Exporter';

sub warning(&) {
    my $warnings = &warns(@_) || [];
    if (@$warnings != 1) {
        warn $_ for @$warnings;
        Carp::croak "Got " . scalar(@$warnings) . " warnings, expected exactly 1"
    }
    return $warnings->[0];
}

sub no_warnings(&) {
    my $warnings = &warns(@_);
    return 1 unless defined $warnings;
    warn $_ for @$warnings;
    return 0;
}

sub warns(&) {
    my @warnings;
    local $SIG{__WARN__} = sub {
        push @warnings => @_;
    };
    my ($ok, $err) = &Test2::Util::try(@_);
    die $err unless $ok;
    return undef unless @warnings;
    return \@warnings;
}

sub lives(&) {
    my $code = shift;
    my ($ok, $err) = &Test2::Util::try($code);
    return 1 if $ok;
    warn $err;
    return 0;
}

sub dies(&) {
    my $code = shift;
    my ($ok, $err) = &Test2::Util::try($code);
    return undef if $ok;
    return $err;
}

sub capture(&) {
    my $code = shift;

    my ($err, $out) = ("", "");

    my ($ok, $e);
    {
        local *STDOUT;
        local *STDERR;

        ($ok, $e) = Test2::Util::try(sub {
            open(STDOUT, '>', \$out) or die "Failed to open a temporary STDOUT: $!";
            open(STDERR, '>', \$err) or die "Failed to open a temporary STDERR: $!";

            $code->();
        });
    }

    die $e unless $ok;

    return {
        STDOUT => $out,
        STDERR => $err,
    };
}

1;
