package Test::Stream::Plugin::LoadPlugin;
use strict;
use warnings;

use Test::Stream::Exporter;
default_exports qw/load_plugin/;
no Test::Stream::Exporter;

sub load_plugin {
    my @caller = caller;
    Test::Stream->load(\@caller, @_);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::LoadPlugin - Load a plugin with full Test::Stream
semantics, but at runtime.

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

When testing plugins it can be useful to load them multiple times with
different arguments. Doing this with C<use Test::Stream ...> isn't helpful as
the C<use> statement makes it happen at BEGIN time. This module provides a
run-time function you can use to load a plugin. The syntax is identical to the
use statements, this is because it uses the same mechanism under the hood.

=head1 SYNOPSIS

    use Test::Stream 'LoadPlugin';

    # The following 2 are identical, except that the use statement happens at
    # begin time, the load_plugin statement happens at run-time.
    load_plugin Plugin => [qw/foo bar/];
    use Test::Stream Plugin => [qw/foo bar/];

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
