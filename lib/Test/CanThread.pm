package Test::CanThread;
use strict;
use warnings;

use Config;

my $works = 1;
$works &&= $] >= 5.008001;
$works &&= $Config{'useithreads'};
$works &&= eval { require threads; 'threads'->import; 1 };

require Test::Stream;

sub import {
    my $class = shift;

    unless ($works) {
        my $ctx = Test::Stream::Context::context();
        $ctx->plan(0, skip_all => "Skip no working threads");
        exit 0;
    }

    if ($INC{'Devel/Cover.pm'}) {
        my $ctx = Test::Stream::Context::context();
        $ctx->plan(0, skip_all => "Devel::Cover does not work with threads yet");
        exit 0;
    }

    while(my $var = shift(@_)) {
        next if $ENV{$var};
        my $ctx = Test::Stream::Context::context();
        $ctx->plan(0, skip_all => "This threaded test will only run when the '$var' environment variable is set.");
        exit 0;
    }

    if ($] == 5.010000) {
        require File::Temp;
        require File::Spec;

        my $perl = File::Spec->rel2abs($^X);
        my ($fh, $fn) = File::Temp::tempfile();
        print $fh <<'        EOT';
            BEGIN { print STDERR "# Checking for thread segfaults\n# " }
            use threads;
            my $t = threads->create(sub { 1 });
            $t->join;
            print STDERR "Threads appear to work\n";
            exit 0;
        EOT
        close($fh);

        my $exit = system(qq{"$perl" "$fn"});

        if ($exit) {
            my $ctx = Test::Stream::Context::context();
            $ctx->plan(0, skip_all => "Threads segfault on this perl");
            exit 0;
        }
    }

    my $caller = caller;
    eval "package $caller; use threads; 1" || die $@;
}

1;

__END__

=head1 NAME

Test::CanThread - Only run tests when threading is supported, optionally conditioned on ENV vars.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head2 BACKWARDS COMPATABILITY SHIM

By default, loading Test-Stream will block Test::Builder and related namespaces
from loading at all. You can work around this by loading the compatability shim
which will populate the Test::Builder and related namespaces with a
compatability implementation on demand.

    use Test::Stream::Shim;
    use Test::Builder;
    use Test::More;

B<Note:> Modules that are experimenting with Test::Stream should NOT load the
shim in their module files. The shim should only ever be loaded in a test file.


=head1 DESCRIPTION

Use this first thing in a test that should be skipped when threading is not
supported. You can also specify that the test should be skipped when specific
environment variables are not set.

=head1 SYNOPSIS

Skip the test if threading is unsupported:

    use Test::CanThread;
    use Test::More;
    ...

Skip the test if threading is unsupported, or any of the specified env vars are
not set:

    use Test::CanThread qw/AUTHOR_TESTING RUN_PROBLEMATIC_TESTS .../;
    use Test::More;
    ...

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

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
