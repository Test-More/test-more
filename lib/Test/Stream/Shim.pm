package Test::Stream::Shim;
use strict;
use warnings;

use Test::Stream::Carp qw/confess cluck/;

# This is an ordered list so that the message is most helpful, in other words
# show the more recognisable modules first when reporting an error.
my @REDIRECT = (
    'Test/More.pm',
    'Test/Builder.pm',
    'Test/Simple.pm',
    'Test/Tester.pm',
    'Test/Builder/Tester.pm',
);

my %REDIRECT = (
    'Test/Builder/Module.pm'       => 'Test::Builder::Module',
    'Test/Builder/Tester/Color.pm' => 'Test::Builder::Tester::Color',
    'Test/Builder/Tester.pm'       => 'Test::Builder::Tester',
    'Test/Builder.pm'              => 'Test::Builder',
    'Test/More.pm'                 => 'Test::More',
    'Test/Simple.pm'               => 'Test::Simple',
    'Test/Tester/CaptureRunner.pm' => 'Test::Tester::CaptureRunner',
    'Test/Tester/Capture.pm'       => 'Test::Tester::Capture',
    'Test/Tester/Delegate.pm'      => 'Test::Tester::Delegate',
    'Test/Tester.pm'               => 'Test::Tester',
    'Test/use/ok.pm'               => 'Test::use::ok',
    'ok.pm'                        => 'ok',
);

check_loaded();

my $LOADED = 0;
sub import {
    my $class = shift;
    my ($arg) = @_;

    if ($arg && $arg eq '-no-compat' && !$LOADED) {
        block_loads();
    }
    else {
        check_loader(caller(0));
        insert_shim();
    }
}

my $SHIM_LOADED   = 0;
my $BLOCKED_LOADS = 0;

sub check_loader {
    my @call = @_;
    my $file = $call[1];
    cluck "Test::Stream::Shim should only be loaded by a test file, $file does not look like a test file"
        unless $file =~ m{\.t$}         # If it ends in a .t assume it is fine
        || $file =~ m{^t(/|\\)}         # If it in the t/ directory
        || $file =~ m{(/|\\)t(/|\\)}    # If there is a 't' dir in the file path.
        || $file =~ m{test}             # Intentionally Lowercase
        || $file eq '-e';               # Allow 1-liners
}

sub block_loads {
    return if $SHIM_LOADED;
    return if $BLOCKED_LOADS++;

    # To make sure nothing has loaded it since the initial check.
    check_loaded();

    for my $file (keys %REDIRECT) {
        $INC{$file} = __FILE__;
        my $pkg = $REDIRECT{$file};
        no strict 'refs';
        @{"$pkg\::ISA"} = ('Test::Stream::Shim::Blocked');
    }
}

sub insert_shim {
    return if $SHIM_LOADED++;

    # To make sure nothing has loaded it since the initial check.
    check_loaded();

    if ($BLOCKED_LOADS--) {
        for my $file (keys %REDIRECT) {
            delete $INC{$file};
            my $pkg = $REDIRECT{$file};
            no strict 'refs';
            @{"$pkg\::ISA"} = ();
        }
    }

    unshift @INC => sub {
        my ($us, $file) = @_;
        return unless $REDIRECT{$file};

        my $rewrite = $file;
        $rewrite =~ s/\.pm$/_stream.pm/;
        require $rewrite;

        $INC{$file} = $INC{$rewrite};

        open(my $fh, '<', \"1");
        return $fh;
    };
}

sub check_loaded {
    my %seen;
     for my $file (@REDIRECT, keys %REDIRECT) {
         next if $seen{$file}++;
         confess "$file has already been loaded, Test::Stream must be loaded first"
             if $INC{$file} && $INC{$file} ne __FILE__;
     }
}

package Test::Stream::Shim::Blocked;
use Test::Stream::Carp qw/confess/;

sub import {
    my $class = shift;
    confess "Test::Stream has blocked the use of '$class', See the Test-Stream documentation for more details";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Shim - Allow test files to mix Test-Stream and Test-Builder
tools.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 SYNOPSIS

    use Test::Stream;
    use Test::Stream::Shim;
    use Test::More;

    ...

    1;

=head1 DESCRIPTION

This is the compatability shim. This module makes it possible to mix
Test-Stream and Test-Builder based tools inside a test file.

B<Note> You should not use this in a test module, only in a test file!.

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
