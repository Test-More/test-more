package Test::Stream::Compare::DNE;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
);

sub name { "<DOES NOT EXIST>" }
sub operator { '!exists' }

sub verify {
    my $ctx = Test::Stream::Context::context;
    $ctx->throw("DNE->verify() should never be called, was DNE used in a non-hash?");
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::DNE - Check that a hash field does not exist.

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

This is a special case check for deep comparisons. This special case can be
used to confirm a hash field does not even exist in a hash. This check will
throw an exception if it is used for anything other than a hash field check.

=head1 SYNOPSIS

    my $dne = Test::Stream::Compare::DNE->new()

    like(
        { a => 1, b => 2,            d => 4 },
        { a => 1, b => 2, c => $dne, d => 4 },
        "Got expected hash, 'c' field does not exist"
    );

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
