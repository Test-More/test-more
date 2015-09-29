package Test::Stream::Plugin::IPC;
use strict;
use warnings;

use Test::Stream::IPC;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/pkg_to_file/;
use Carp qw/croak confess/;

use Test::Stream::Plugin;

sub load_ts_plugin {
    my $class = shift;
    my $caller = shift;

    my @drivers;
    my %params;

    for my $arg (@_) {
        if ($arg =~ m/^-(.*)$/) {
            $params{$1}++;
        }
        elsif ($arg =~ m/^\+(.+)$/) {
            push @drivers => $1;
        }
        else {
            push @drivers => "Test::Stream::IPC::$arg";
        }
    }

    for my $driver (@drivers) {
        my $file = pkg_to_file($driver);
        unless(eval { require $file; 1 }) {
            my $error = $@;
            die $error unless $error =~ m/^Can't locate/;
            next;
        }
        Test::Stream::IPC->register_driver($driver);
    }

    Test::Stream::IPC->enable_polling if delete $params{poll};

    if (delete $params{cull}) {
        no strict 'refs';
        *{"$caller->[0]\::cull"} = \&cull
    }

    if (my @bad = keys %params) {
        confess "Invalid parameters: " . join ', ', map { "'-$_'" } @bad;
    }
}

sub cull {
    my $ctx = context();
    $ctx->hub->cull;
    $ctx->release;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::IPC - Plugin to load and configure IPC support.

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

The L<Test::Stream> IPC layer provided by L<Test::Stream::IPC> is responsible
for sending events between threads and processes. This is necessary for any
test files that fork or use threads. This plugin provides an interface to
loading and using the IPC layer.

=head1 SYNOPSIS

    use Test::Stream qw/IPC/;

You may wish to enable polling, which will pull in results frequently, by
default results from other threads and processes all come it at once at the end
of testing.

    use Test::Stream IPC => [qw/-poll/];

You can also import the C<cull()> function that can be used to pull results in
on demand.

    use Test::Stream IPC => [qw/-cull/];

    cull();

You can also specify a list of drivers to try in order:

    use Test::Stream IPC => [
        'MyIPCDriver',
        '+Fully::Qualified::Driver::Package',
        'Files',
    ];

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
