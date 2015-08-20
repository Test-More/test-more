package Test::Stream::Plugin;
use strict;
use warnings;

use Test::Stream::Exporter;
default_export import => sub {
    my $class = shift;
    my @caller = caller;
    $class->load_ts_plugin(\@caller, @_);
};
no Test::Stream::Exporter;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin - Simple helper for writing plugins

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

This module provides an import method that wraps around a typical
Test::Stream::Plugin so that it can be used directly.

B<Note>: This plugin is not necessary if your plugin uses
L<Test::Stream::Exporter> and does not have a custom C<import> method.

=head1 SYNOPSIS

    package Test::Stream::Plugin::MyPlugin;
    use strict;
    use warnings;

    # Provides an 'import' method for us that delegates to load_ts_plugin()
    use Test::Stream::Plugin;

    sub load_ts_plugin {
        my $class = shift;
        my ($caller, @args) = @_;
        ...
    }

    1;

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
