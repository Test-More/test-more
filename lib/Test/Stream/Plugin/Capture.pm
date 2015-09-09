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

    my ($ok, $e);
    {
        local *STDOUT;
        local *STDERR;

        ($ok, $e) = try {
            open(STDOUT, '>', \$out) or die "Failed to open a temporary STDOUT: $!";
            open(STDERR, '>', \$err) or die "Failed to open a temporary STDERR: $!";

            $code->();
        };
    }

    die $e unless $ok;

    return {
        STDOUT => $out,
        STDERR => $err,
    };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Capture - Plugin for capturing STDERR and STDOUT.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This plugin provides the C<capture { ... }> function which can be used to
capture all STDERR and STDOUT output from the code in the provided codeblock.
This will not intercept TAP output from Test::Stream itself, so it is safe to
run tests within the block.

=head1 SYNOPSIS

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

=head1 EXPORTS

=over 4

=item $out = capture { ... }

Captures all STDERR and STDOUT output within the codeblock. C<$out> will be a
hashref with STDERR and STDOUT as keys. All output is combined into a single
string per handle.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
