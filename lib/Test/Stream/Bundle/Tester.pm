package Test::Stream::Bundle::Tester;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (
        qw/Intercept Grab LoadPlugin Context/,
        Compare => ['-all'],
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Bundle::Tester - Bundle for testing test tools.

=head1 DESCRIPTION

Plugins that are useful when testing test tools and plugins. This includes
tools for intercepting and validating events, as well as all the exports
provided by the Compare plugin.

=head1 SYNOPSIS

    use Test::Stream Core, -Tester;

    is(
        intercept { ok(1, "pass") },
        array {
            event Ok => sub {
                call pass => T();
                call name => 'pass';
            };
            end;
        },
        "Intercepted an event"
    );

    done_testing;

=head1 INCLUDED PLUGINS AND BUNDLES

=head2 Test::Stream::Plugin::Compare

Unlike the default bundle, every tool exported by the Compare plugin is
imported.

=head2 Test::Stream::Plugin::Intercept

Provides the C<intercept { ... }> function, this is used to intercept events.

=head2 Test::Stream::Plugin::Grab

An alternative way to intercept events, this one does not add stack frames.

=head2 Test::Stream::Plugin::LoadPlugin

Allows you to dynamically load plugins as needed.

=head2 Test::Stream::Plugin::Context

Provides the C<context()> function.

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
