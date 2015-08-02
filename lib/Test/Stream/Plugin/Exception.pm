package Test::Stream::Plugin::Exception;
use strict;
use warnings;

use Test::Stream::Util qw/try/;
use Carp qw/croak/;

use Test::Stream::Exporter;
default_exports qw/lives dies/;
no Test::Stream::Exporter;

sub lives(&) {
    my $code = shift;
    my ($ok, $err) = &try($code);
    return 1 if $ok;
    warn $err;
    return 0;
}

sub dies(&) {
    my $code = shift;
    my ($ok, $err) = &try($code);
    return undef if $ok;
    return $err;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Exception - Simple tools to help test exceptions.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 SYNOPSIS

    # Loads Exception, we also need 'More', so load that as well.
    use Test::Stream qw/More Exception/;

    ok(lives { ... }, "codeblock did not die");

    like(dies { die 'xxx' }, qr/xxx/, "codeblock threw expected exception");

=head1 EXPORTS

=over 4

=item $bool = lives { ... }

If the codeblock does not throw any exception this will return true. If the
codeblock does throw an exception this will return false, after printing the
exception as a warning.

    ok(lives { ... }, "codeblock did not die");

=item $error = dies { ... }

This will return undef if the codeblock does not throw an exception, otherwise
it returns the exception. Note, if your exception is an empty string or 0 it is
your responsibility to check that the error is defined instead of using a
simple boolean check.

    ok( defined dies { die 0 }, "died" );

    like(dies { die 'xxx' }, qr/xxx/, "codeblock threw expected exception");

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
