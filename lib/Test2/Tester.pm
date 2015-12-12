package Test2::Tester;
use strict;
use warnings;

use Scalar::Util qw/blessed/;

use Test2::Util qw/try/;
use Test2::Context qw/context/;

use Test2::Hub::Interceptor();
use Test2::Hub::Interceptor::Terminator();

our @EXPORT = qw{
    intercept

    ok
    is   isnt
    like unlike
    diag note

    is_deeply

    warnings
    exception

    plan
    skip_all
    done_testing
};
use base 'Exporter';

sub intercept(&) {
    my $code = shift;

    my $ctx = context();

    my $ipc;
    if ($INC{'Test2/IPC.pm'}) {
        my ($driver) = Test2::IPC->drivers;
        $ipc = $driver->new;
    }

    my $hub = Test2::Hub::Interceptor->new(
        ipc => $ipc,
        no_ending => 1,
    );

    my @events;
    $hub->listen(sub { push @events => $_[1] });

    $ctx->stack->top; # Make sure there is a top hub before we begin.
    $ctx->stack->push($hub);
    my ($ok, $err) = try {
        $code->(
            hub => $hub,
            context => $ctx->snapshot,
        );
    };
    $hub->cull;
    $ctx->stack->pop($hub);

    my $trace = $ctx->trace;
    $ctx->release;

    die $err unless $ok
        || (blessed($err) && $err->isa('Test2::Hub::Interceptor::Terminator'));

    $hub->finalize($trace, 1)
        if $ok
        && !$hub->no_ending
        && !$hub->state->ended;

    return \@events;
}

sub ok($;$@) {
    my ($bool, $name, @diag) = @_;
    my $ctx = context();
    $ctx->ok($bool, $name, \@diag);
    $ctx->release;
    return $bool ? 1 : 0;
}

sub is($$;$@) {
    my ($got, $want, $name, @diag) = @_;
    my $ctx = context();

    my $bool;
    if (defined($got) && defined($want)) {
        $bool = "$got" eq "$want";
    }
    elsif (defined($got) xor defined($want)) {
        $bool = 0;
    }
    else { # Both are undef
        $bool = 1;
    }

    unless ($bool) {
        $got  = '*NOT DEFINED*' unless defined $got;
        $want = '*NOT DEFINED*' unless defined $want;
        unshift @diag => (
            "GOT:      $got",
            "EXPECTED: $want",
        );
    }

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;
    return $bool;
}

sub isnt($$;$@) {
    my ($got, $want, $name, @diag) = @_;
    my $ctx = context();

    my $bool;
    if (defined($got) && defined($want)) {
        $bool = "$got" ne "$want";
    }
    elsif (defined($got) xor defined($want)) {
        $bool = 1;
    }
    else { # Both are undef
        $bool = 0;
    }

    unshift @diag => "Strings are the same (they should not be)"
        unless $bool;

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;
    return $bool;
}

sub like($$;$@) {
    my ($thing, $pattern, $name, @diag) = @_;
    my $ctx = context();

    my $bool;
    if (defined($thing)) {
        $bool = "$thing" =~ $pattern;
        unshift @diag => (
            "Value: $thing",
            "Does not match: $pattern"
        ) unless $bool;
    }
    else {
        $bool = 0;
        unshift @diag => "Got an undefined value.";
    }

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;
    return $bool;
}

sub unlike($$;$@) {
    my ($thing, $pattern, $name, @diag) = @_;
    my $ctx = context();

    my $bool;
    if (defined($thing)) {
        $bool = "$thing" !~ $pattern;
        unshift @diag => (
            "Unexpected pattern match (it should not match)",
            "Value:   $thing",
            "Matches: $pattern"
        ) unless $bool;
    }
    else {
        $bool = 0;
        unshift @diag => "Got an undefined value.";
    }

    $ctx->ok($bool, $name, \@diag);
    $ctx->release;
    return $bool;
}

sub is_deeply($$;$@) {
    my ($got, $want, $name, @diag) = @_;
    my $ctx = context();

    no warnings 'once';
    require Data::Dumper;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Deparse  = 1;
    local $Data::Dumper::Freezer = 'XXX';
    local *UNIVERSAL::XXX = sub {
        my ($thing) = @_;
        if (ref($thing)) {
            $thing = {%$thing}  if "$thing" =~ m/=HASH/;
            $thing = [@$thing]  if "$thing" =~ m/=ARRAY/;
            $thing = \"$$thing" if "$thing" =~ m/=SCALAR/;
        }
        $_[0] = $thing;
    };

    my $g = Data::Dumper::Dumper($got);
    my $w = Data::Dumper::Dumper($want);

    my $bool = $g eq $w;

    $ctx->ok($bool, $name, [$g, $w, @diag]);
    $ctx->release;
    return $bool;
}

sub diag {
    my $ctx = context();
    $ctx->diag( join '', @_ );
    $ctx->release;
}

sub note {
    my $ctx = context();
    $ctx->note( join '', @_ );
    $ctx->release;
}

sub skip_all {
    my ($reason) = @_;
    my $ctx = context();
    $ctx->plan(0, SKIP => $reason);
    $ctx->release if $ctx;
}

sub plan {
    my ($max) = @_;
    my $ctx = context();
    $ctx->plan($max);
    $ctx->release;
}

sub done_testing {
    my $ctx = context();
    $ctx->hub->finalize($ctx->trace, 1);
    $ctx->release;
}

sub warnings(&) {
    my $code = shift;
    my @warnings;
    local $SIG{__WARN__} = sub { push @warnings => @_ };
    $code->();
    return \@warnings;
}

sub exception(&) {
    my $code = shift;
    local ($@, $!, $SIG{__DIE__});
    my $ok = eval { $code->(); 1 };
    return $ok ? undef : $@;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Tester - Essential basic tools for testing Test2, and Test2 based
tools.

=head1 DESCRIPTION

B<This is not a tool you want for normal testing!!>

This library exports some essential tools needed for Test2, and frameworks
built on it, to test themselves. These tools are bare-bones and intended only
for Test2, and frameworks built on top of it. Think of this as a testing
library for bootstrapping testing libraries.

=head1 SYNOPSIS

    use Test2::Tester;

    my $events = intercept {
        ok(1, 'foo');
        ok(0, 'bar');
    };

    is(@$events, 2, "intercepted 2 events.");
    ok($events->[0]->pass, "first event passed");

    done_testing;

=head1 EXPORTS

=over 4

=item $events = intercept { ... }

This lets you intercept all events inside the codeblock. All the events will be
returned in an arrayref.

    my $events = intercept {
        ok(1, 'foo');
        ok(0, 'bar');
    };
    is(@$events, 2, "intercepted 2 events.");

There are also 2 named parameters passed in, C<context> and C<hub>. The
C<context> passed in is a snapshot of the context for the C<intercept()> tool
itself, referencing the parent hub. The C<hub> parameter is the new hub created
for the C<intercept> run.

    my $events = intercept {
        my %params = @_;

        my $outer_ctx = $params{context};
        my $our_hub   = $params{hub};

        ...
    };

By default the hub used has C<no_ending> set to true. This will prevent the hub
from enforcing that you issued a plan and ran at least 1 test. You can turn
enforcement back one like this:

    my %params = @_;
    $params{hub}->set_no_ending(0);

With C<no_ending> turned off, C<$hub->finalize()> will run the post-test checks
to enforce the plan and that tests were run. In many cases this will result in
additional events in your events array.

B<Note:> the C<$ENV{TS_TERM_SIZE}> environment variable is set to 80 inside the
intercept block. This is done to ensure consistency for the block across
machines and platforms. This is essential for predictable testing of
diagnostics, which may render tables or use the terminal size to change
behavior.

=item $bool = ok($bool)

=item $bool = ok($bool, $name)

=item $bool = ok($bool, $name, @diag)

Fire of an 'Ok' event. If C<$bool> is true the test passes, otherwise it fails.
C<$name> is an optional name of the test. Any extra arguments will be printed
as diagnostics in event of a test failure.

=item $bool = is($got, $want)

=item $bool = is($got, $want, $name)

=item $bool = is($got, $want, $name, @diag)

Check that 2 strings are equal. If th strings are not equal the test fails.

=item $bool = isnt($got, $want)

=item $bool = isnt($got, $want, $name)

=item $bool = isnt($got, $want, $name, @diag)

Check that 2 strings are not equal

=item $bool = like($thing, qr/pattern/)

=item $bool = like($thing, qr/pattern/, $name)

=item $bool = like($thing, qr/pattern/, $name, @diag)

Check that a string matches the pattern.

=item $bool = unlike($thing, qr/pattern/)

=item $bool = unlike($thing, qr/pattern/, $name)

=item $bool = unlike($thing, qr/pattern/, $name, @diag)

Check that a string does not match the pattern.

=item $bool = is_deeply($got, $want)

=item $bool = is_deeply($got, $want, $name)

=item $bool = is_deeply($got, $want, $name, @diag)

This is an extremely limited version of C<is_deeply()>. Ultimately this simply
dumps both data structures using C<Data::Dumper> then compares the strings. If
there is a problem the diagnostics are simply a dump of both structures.

B<This is not an is_deeply you want to use everywhere>. This is provided as a
basic implementation of an essential tool.

=item diag($msg)

Issue a diagnostics message (sent to STDERR)

=item note($msg)

Issue a notation message (sent to STDOUT)

=item plan($count)

Set the test plan.

=item skip_all($reason)

Skip the test file.

=item done_testing()

Set the plan and stop all testing.

=item $warnings = warnings { ... }

Capture all warnings from the codeblock. Result is an arrayref of warnings.

=item $exception = exception { ... }

Capture an exception from the specified codeblock.

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

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

See F<http://dev.perl.org/licenses/>

=cut
