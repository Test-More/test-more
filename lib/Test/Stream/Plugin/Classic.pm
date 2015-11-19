package Test::Stream::Plugin::Classic;
use strict;
use warnings;

use Test::Stream::Exporter qw/import default_exports/;
default_exports qw/is is_deeply isnt like unlike/;
no Test::Stream::Exporter;

use Scalar::Util qw/blessed/;

use Test::Stream::Compare qw/-all/;
use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/rtype/;

use Test::Stream::Compare::String();
use Test::Stream::Compare::Pattern();

use Test::Stream::Plugin::Compare();

sub is($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&is_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub isnt($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&isnt_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub is_convert {
    my ($thing) = @_;
    return Test::Stream::Compare::Undef->new()
        unless defined $thing;
    return Test::Stream::Compare::String->new(input => $thing);
}

sub isnt_convert {
    my ($thing) = @_;
    return Test::Stream::Compare::Undef->new()
        unless defined $thing;
    my $str = Test::Stream::Compare::String->new(input => $thing, negate => 1);
}

sub like($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my $delta = compare($got, $exp, \&like_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub unlike($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my $delta = compare($got, $exp, \&unlike_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub like_convert {
    my ($thing) = @_;
    return Test::Stream::Compare::Pattern->new(
        pattern => $thing,
    );
}

sub unlike_convert {
    my ($thing) = @_;
    return Test::Stream::Compare::Pattern->new(
        negate  => 1,
        pattern => $thing,
    );
}

sub is_deeply($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&Test::Stream::Plugin::Compare::strict_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Classic - Classing (Test::More) style is and is_deeply.

=head1 DESCRIPTION

This provides C<is()> and C<is_deeply()> functions that behave close to the way
they did in L<Test::More>, unlike the L<Test::Stream::Plugin::Compare> plugin
which has enhanced them (or ruined them, depending on who you ask).

=head1 SYNOPSIS

    use Test::Stream 'Classic';

    is($got, $expect, "these are the same when stringified");
    isnt($got, $unexpect, "these are not the same when stringified");

    like($got, qr/.../, "'got' matches the pattern");
    unlike($got, qr/.../, "'got' does not match the pattern");

    is_deeply($got, $expect, "These structures are same when checked deeply");

=head1 EXPORTS

=over 4

=item $bool = is($got, $expect)

=item $bool = is($got, $expect, $name)

=item $bool = is($got, $expect, $name, @diag)

This does a string comparison of the 2 arguments. If the 2 arguments are the
same after stringification the test passes. The test will also pas sif both
arguments are undef.

The test C<$name> is optional.

The test C<@diag> is optional, it is extra diagnostics messages that will be
displayed if the test fails. The diagnostics are ignored if the test passes.

It is important to note that this tool considers C<"1"> and C<"1.0"> to not be
equal as it uses a string comparison.

See L<Test::Stream::Plugin::Compare> if you want a C<is()> function that tries
to be smarter for you.

=item $bool = isnt($got, $dont_expect)

=item $bool = isnt($got, $dont_expect, $name)

=item $bool = isnt($got, $dont_expect, $name, @diag)

This is the inverse of C<is()>, it passes when the strings are not the same.

=item $bool = like($got, $pattern)

=item $bool = like($got, $pattern, $name)

=item $bool = like($got, $pattern, $name, @diag)

Check if C<$got> matches the specified pattern. Will fail if it does not match.

The test C<$name> is optional.

The test C<@diag> is optional, it is extra diagnostics messages that will be
displayed if the test fails. The diagnostics are ignored if the test passes.

=item $bool = unlike($got, $pattern)

=item $bool = unlike($got, $pattern, $name)

=item $bool = unlike($got, $pattern, $name, @diag)

This is the inverse of C<like()>. This will fail if C<$got> matches
C<$pattern>.

=item $bool = is_deeply($got, $expect)

=item $bool = is_deeply($got, $expect, $name)

=item $bool = is_deeply($got, $expect, $name, @diag)

This does a deep check, it compares the structures in C<$got> with those in
C<$expect>. It will recurse into hashrefs, arrayrefs, and scalar refs. All
other values will be stringified and compared as strings. It is important to
note that this tool considers C<"1"> and C<"1.0"> to not be equal as it uses a
string comparison.

This is the same as C<Test::Stream::Plugin::Compare::is()>.

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
