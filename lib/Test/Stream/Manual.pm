package Test::Stream::Manual;
use strict;
use warnings;

1;

__END__

=head1 NAME

Test::Stream::Manual - Manual for Test::Stream

=head1 INTRODUCTION TO TESTING

If you are completely new to wiriting tests, or at least new to doing it in
perl, you should read this first: L<Test::Stream::Manual::BeginnerTutorial>.

=head1 ECOSYSTEM OVERVIEW

=head2 INFRASTRUCTURE

Any module under the L<Test::Stream> namespace is considered infrastructure,
unless they are plugins, bundles, or third party events. If a module is in the
C<Test::Stream::> namespace, and not under C<Plugin::>, C<Bundle::>,
C<Event::>, or C<Hub::> then by convention it is infrastructure, and probably
not intended for most people to use directly.

See L<Test::Stream::Manual::Infrastructure> for more information about the
infrastructure.

=head2 PLUGINS

Plugins are the recommended way of adding new tools based on the
L<Test::Stream> infrastructure. Plugins can either be loaded directly, or
listed when loading L<Test::Stream> itself, possibly in a bundle. See
L</"CORE PLUGINS"> for a list of available plugins. See
L<Test::Stream::Manual::Tooling> for information about writing a plugin.

=head2 BUNDLES

Bundles are collections of plugins listed together to reduce boilerplate. This
is intended to replace the L<Test::Builder> practice of writing modules that
implement new functionality while also pulling in other modules. Using bundles
is a better system since it prevents an author from forcing their assumptions
on others. Plugins and Bundles should be kept seperate so that test authors can
pick and choose functionality without worrying about what else it might pick
for them.

=head2 EVENTS

L<Test::Stream> works by generating events and handing them off to the right
places. There are several core events types, but third party tools can also add
their own. Adding you own event type to the C<Test::Stream::Event::> namespace
is perfectly fine, nobody will yell at you.

=head2 HUBS

L<Test::Stream> uses the concept of a 'Hub' through which all events flow. The
design in L<Test::Stream> allows you to push hubs onto a stack in order to
temporarily intercept events. In many cases it is necessary to subclass
L<Test::Stream::Hub> to add or alter functionality. When you must do this you
may add new modules under the C<Test::Stream::Hub::> namespace.

=head1 CORE PLUGINS

=head1 CORE BUNDLES

=head1 OTHER MANUAL PAGES

=over 4

=item L<Test::Stream::Manual::BeginnerTutorial>

This is a gentle introduction to testing.

=item L<Test::Stream::Manual::Tooling>

This document explains how to write plugins, bundles, and other extensions to
L<Test::Stream>.

=item L<Test::Stream::Manual::Infrastructure>

This document goes into detail about the L<Test::Stream> infrastructure. This
is useful to anyone writing plugins, but it is more useful to anyone that
wishes to work on L<Test::Stream> directly.

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
