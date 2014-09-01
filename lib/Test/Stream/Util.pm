package Test::Stream::Util;
use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/reftype blessed/;
use Test::Stream::Exporter qw/import export_to exports/;

exports qw/try protect is_regex/;

Test::Stream::Exporter->cleanup();

sub protect(&) {
    my $code = shift;

    my ($ok, $error);
    {
        local ($@, local $!);
        $ok = eval { $code->(); 1 } || 0;
        $error = $@ || "Error was squashed!\n";
    }
    die $error unless $ok;
    return $ok;
}

sub try(&) {
    my $code = shift;
    my $error;
    my $ok;

    {
        local ($@, $!, $SIG{__DIE__});
        $ok = eval { $code->(); 1 } || 0;
        unless($ok) {
            $error = $@ || "Error was squashed!\n";
        }
    }

    return wantarray ? ($ok, $error) : $ok;
}

sub is_regex {
    my ($pattern) = @_;

    return undef unless defined $pattern;

    if (defined &re::is_regexp) {
        return re::is_regexp($pattern) || undef;
    }

    my $type = reftype($pattern) || return undef;

    return $pattern if $type =~ m/^regexp?$/i;
    return undef unless $type eq 'SCALAR';
    return $pattern if $pattern =~ m/^\(\?.+:.*\)$/;
}

1;

__END__

=head1 NAME

Test::Stream::Util

=head1 DESCRIPTION

Tools for generating accessors and other object bits and pieces.

=head1 SYNOPSYS

    ...

=head1 EXPORTS

=over 4

=item $success = try { ... }

=item ($success, $error) = try { ... }

Eval the codeblock, return success or failure, and optionally the error
message. This code protects $@ and $!, they will be restored by the end of the
run. This code also temporarily blocks $SIG{DIE} handlers.

=item protect { ... }

Similar to try, except that it does not catch exceptions. The idea here is to
protect $@ and $! from changes. $@ and $! will be restored to whatever they
were before the run so long as it is successful. If the run fails $! will still
be restored, but $@ will contain the exception being thrown.

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

