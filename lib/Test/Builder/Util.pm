package Test::Builder::Util;
use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/reftype blessed/;
use Test::Builder::Exporter qw/import export_to exports package_sub/;

exports qw/
    try protect
    package_sub
    is_tester
    init_tester
/;

Test::Builder::Exporter->cleanup();

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

sub is_tester {
    my $pkg = shift;
    return unless package_sub($pkg, 'TB_TESTER_META');
    return $pkg->TB_TESTER_META;
}

sub init_tester {
    my $pkg = shift;
    return $pkg->TB_TESTER_META if package_sub($pkg, 'TB_TESTER_META');

    no strict 'refs';
    my $todo = \*{"$pkg\::TODO"};
    use strict 'refs';

    my $meta = { todo => $todo, encoding => 'legacy' };

    *{"$pkg\::TB_TESTER_META"} = sub { $meta };

    return $meta;
}

1;

__END__

=head1 NAME

Test::Builder::Util - Internal tools for Test::Builder and friends

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

=item $coderef = package_sub($package, $subname)

Find a sub in a package, returns the coderef if it is present, otherwise it
returns undef. This is similar to C<< $package->can($subname) >> except that it
ignores inheritance.

=item $meta = is_tester($package)

Check if a package is a tester, return the metadata if it is.

=item $meta = init_tester($package)

Check if a package is a tester, return the metadata if it is, otherwise turn it
into a tester and return the newly created metadata.

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

