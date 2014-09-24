package Test::Stream::Toolset;
use strict;
use warnings;

use Test::Stream::Context qw/context/;
use Test::Stream::Meta    qw/is_tester init_tester/;

# Preload these so the autoload is not necessary
use Test::Stream::Event::Bail;
use Test::Stream::Event::Child;
use Test::Stream::Event::Diag;
use Test::Stream::Event::Finish;
use Test::Stream::Event::Note;
use Test::Stream::Event::Ok;
use Test::Stream::Event::Plan;
use Test::Stream::Event::Subtest;

use Test::Stream::Exporter qw/import export_to default_exports/;
default_exports qw/is_tester init_tester context/;
Test::Stream::Exporter->cleanup();

1;

=head1 NAME

Test::Stream::Toolset - Helper for writing testing tools

=head1 TEST COMPONENT MAP

  [Test Script] > [Test Tool] > [Test::Stream] > [Event Formatter]
                       ^
                  You are here

A test script uses a test tool such as L<Test::More>, which uses Test::Provider
to produce events. The events are sent to L<Test::Stream> which then
forwards them on to one or more formatters. By default the stream will produce
TAP forall events.

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
