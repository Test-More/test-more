package Test::Stream::Provider;
use strict;
use warnings;

use Test::Stream::Context;

use Test::Stream::Util qw/init_tester/;
use Exporter qw/import/;

our @EXPORT = ('context', 'anoint');

BEGIN { *context = \&Test::Stream::Context::context }

sub anoint {
    my ($target, $oil) = @_;
    $oil ||= caller;

    my $meta = init_tester($target);
    $meta->{anointed_by}->{$oil} = 1;
}

1;

=head1 NAME

Test::Stream::Provider - Helper for writing testing tools

=head1 TEST COMPONENT MAP

  [Test Script] > [Test Tool] > [Test::Builder] > [Test::Bulder::Stream] > [Event Formatter]
                       ^
                  You are here

A test script uses a test tool such as L<Test::More>, which uses Test::Builder
to produce events. The events are sent to L<Test::Stream> which then
forwards them on to one or more formatters. The default formatter is
L<Test::Stream::Fromatter::TAP> which produces TAP output.

=head1 DESCRIPTION

This package provides you with tools to write testing tools. It makes your job
of integrating with L<Test::Builder> and other testing tools much easier.

=head1 HOW DO I TEST MY TEST TOOLS?

See L<Test::Tester2>

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
