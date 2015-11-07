package Test::Stream::Plugin::AuthorTest;
use strict;
use warnings;

use Test::Stream::Context qw/context/;
use Test::Stream::Plugin;

sub load_ts_plugin {
    my $class = shift;
    my ($caller, $var) = @_;
    $var ||= 'AUTHOR_TESTING';
    return if $ENV{$var};

    my $ctx = context();
    $ctx->plan(0, SKIP => "Author test, set the $var environment variable to run it");
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::AuthorTest - Only run a test when AUTHOR_TESTING is true.

=head1 DESCRIPTION

It is common practice to write tests that are only run when the AUTHOR_TESTING,
or similar environment variable is set. This module automates the (admitedly
trivial) work of creating such a test.

=head1 SYNOPSIS

    use Test::Stream qw/... AuthorTest/;

    ...

    done_testing;

Or directly:

    use Test::Stream::Plugin::AuthorTest;

You can also specify a variable name to use instead of AUTHOR_TESTING

    use Test::Stream AuthorTest => ['THE_VAR'];

or

    use Test::Stream::Plugin::AuthorTest qw/THE_VAR/;

=head1 MANUAL

L<Test::Stream::Manual> is a good place to start when searching for
documentation.

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
