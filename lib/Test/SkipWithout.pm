package Test::SkipWithout;
use strict;
use warnings;

use Test::Stream qw/context/;

sub import {
    my $class = shift;
    my ($module, $version) = @_;

    my $ctx = context();

    my $ok = eval qq{require $module; 1};
    my $err = $@;

    unless ($ok) {
        # This will probably break in perl5i since it changes the message, oh well.
        if ($err =~ m/Can't locate .* in \@INC/) {
            $ctx->plan(0, skip_all => "$module is not installed, skipping test.");
            exit 0;
        }

        my ($package, $file, $line) = $ctx->call;
        die "Error loading module '$module' at $file line $line.\n$err";
    }

    return unless $version;

    $ok = eval {$module->VERSION($version)};
    $err = $@;

    unless ($ok) {
        if ($err =~ m/^($module version \S+ required--this is only version \S+) at/) {
            $ctx->plan(0, skip_all => $1);
            exit 0;
        }

        my ($package, $file, $line) = $ctx->call;
        die "Error checking version for module '$module' at $file line $line.\n$err";
    }
}

1;

__END__

=head1 NAME

Test::SkipWithout - Skip a test if a module is missing, or an insufficient
version.

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

Sometimes a test should only run if specific modules are installed. Other times
a test should only run when a sufficient version of a module is available. This
module lets you do this quickly without writing your own evals.

This Module will skip if the conditions are not met. It is also smart enough to
notice when a module fails to load, or fails its version check due to an
exception. All exceptions are rethrown except for those related to a version
mismatch or module not being installed.

=head1 SYNOPSYS

    use Test::More;

    use Test::SkipWithout 'My::Widget';

    my $widget = My::Widget->new;

    ok($widget, "Made a widget!");

    done_testing;

You can also specify a minimum version

    use Test::More;

    use Test::SkipWithout 'My::Widget' => '2.005';

    my $widget = My::Widget->new;

    ok($widget, "Made a widget!");

    done_testing;

=head1 AUTHORS

Chad Granum L<exodist7@gmail.com>

=head1 COPYRIGHT

Copyright (C) 2014 Chad Granum

Test-SkipWithout is free software; Standard perl licence.

Test-SkipWithout is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the license for more details.
