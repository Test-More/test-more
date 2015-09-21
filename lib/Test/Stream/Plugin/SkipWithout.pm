package Test::Stream::Plugin::SkipWithout;
use strict;
use warnings;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/pkg_to_file/;
use Scalar::Util qw/reftype/;

use Test::Stream::Plugin;

sub load_ts_plugin {
    my $class = shift;
    my $caller = shift;
    for my $arg (@_) {
        if (ref $arg) {
            check_versions($caller, $arg);
        }
        elsif ($arg =~ m/^v?\d/) {
            check_perl_version($caller, $arg);
        }
        else {
            check_installed($caller, $arg);
        }
    }
}

sub skip {
    my ($msg) = @_;
    my $ctx = context();
    $ctx->plan(0, SKIP => $msg);
}

sub check_installed {
    my ($caller, $mod) = @_;
    my $file = pkg_to_file($mod);
    return if eval { require $file; 1 };
    my $error = $@;
    return skip("Module '$mod' is not installed")
        if $error =~ m/Can't locate \Q$file\E in \@INC/;

    # Some other error, rethrow it.
    die $error;
}

sub check_perl_version {
    my ($caller, $ver) = @_;
    return if eval "no warnings 'portable'; require $ver; 1";
    my $error = $@;
    if ($error =~ m/^(Perl \S* required)/i) {
        return skip($1);
    }

    # Other Error
    die $error;
}

sub check_versions {
    my ($caller, $ref) = @_;
    my $type = reftype($ref) || "";
    die "'$ref' is not a valid import argument to " . __PACKAGE__ . " at $caller->[1] line $caller->[2].\n"
        unless $type eq 'HASH';

    for my $mod (sort keys %$ref) {
        my $ver = $ref->{$mod};
        check_installed($caller, $mod);
        return if eval { $mod->VERSION($ver); 1 };
        chomp(my $error = $@);
        $error =~ s/ at .*$//;
        skip($error);
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::SkipWithout - Plugin to skip tests if certain package
requirements are not met.

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

Sometimes you have tests that are nice to run, but depend on tools that may not
be available. Instead of adding the tool as a dep, or making the test always
skip, it is common to make the test run conditionally. This package helps make
that possible.

This module is modeled after L<Test::Requires>. This module even stole most of
the syntax. The difference is that this module is based on L<Test::Stream>
directly, and does not go through L<Test::Builder>. Another difference is that
the packages you check for are not imported into your namespace for you, this
is intentional.

=head1 SYNOPSIS

    use Test::Stream SkipWithout => [
        'v5.10',                 # minimum perl version
        'Necessary::Package',    # We need this, we do not care what version it is

        # A hashref can be used to specify modules + minimum versions
        {
            'Scalar::Util' => '1.3',    # We need at least this version of Scalar::Util
            'Some::Tool'   => '2.5',    # We need version 2.5 of Some::Tool
        },
    ];

    # The tools and features are not imported for us, so we import them here.
    # This gives us control over the import arguments as well.
    use v5.10;
    use Necessary::Package qw/foo bar/;
    use Scalar::Util qw/blessed reftype/;
    use Some::Tool qw/do_it/;

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
