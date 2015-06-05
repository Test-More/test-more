package Test::Stream::Subtest;
use strict;
use warnings;

use Test::Stream::Subtest::Hub;
use Test::Stream::Context qw/context/;

use Test::Stream::Event::Subtest;

use Test::Stream::Util qw/try/;

use Test::Stream::Exporter;
exports qw/subtest_streamed subtest_buffered/;
no Test::Stream::Exporter;

sub subtest_streamed {
    my ($name, $code, @args) = @_;
    my $ctx = context();
    my $pass = _subtest($name, $code, 0, @args);
    $ctx->release;
    return $pass;
}

sub subtest_buffered {
    my ($name, $code, @args) = @_;
    my $ctx = context();
    my $pass = _subtest($name, $code, 1, @args);
    $ctx->release;
    return $pass;
}

sub _subtest {
    my ($name, $code, $buffered, @args) = @_;

    my $ctx = context();

    $ctx->note("Subtest: $name") unless $buffered;

    my $parent = $ctx->hub;

    my $hub = $ctx->stack->new_hub(
        class => 'Test::Stream::Subtest::Hub',
    );

    my @events;
    $hub->set_nested( $parent->isa('Test::Stream::Subtest::Hub') ? $parent->nested + 1 : 1 );
    $hub->listen(sub { push @events => $_[1] });
    $hub->format(undef) if $buffered;

    $hub->set_parent_todo($ctx->debug->todo);

    my ($ok, $err, $finished);
    TS_SUBTEST_WRAPPER: {
        ($ok, $err) = try { $code->(@args) };

        # They might have done 'BEGIN { skip_all => "whatever" }'
        if (!$ok && $err =~ m/Label not found for "last TS_SUBTEST_WRAPPER"/) {
            $ok  = undef;
            $err = undef;
        }
        else {
            $finished = 1;
        }
    }
    $ctx->stack->pop($hub);

    my $dbg = $ctx->debug;

    if (!$finished) {
        if(my $bailed = $hub->bailed_out) {
            $ctx->bail($bailed->reason);
        }
        my $code = $hub->exit_code;
        $ok = !$code;
        $err = "Subtest ended with exit code $code" if $code;
    }

    $hub->finalize($dbg, 1)
        if $ok
        && !$hub->no_ending
        && !$hub->state->ended;

    my $pass = $ok && $hub->state->is_passing;
    my $e = $ctx->build_event(
        'Subtest',
        pass => $pass,
        name => "Subtest: $name",
        buffered  => $buffered,
        subevents => \@events,
    );

    $e->set_diag([
        $e->default_diag,
        $ok ? () : ("Caught exception in subtest: $err"),
    ]) unless $pass;

    $ctx->hub->send($e);

    $ctx->release;
    return $hub->state->is_passing;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Subtest - Tools for writing subtests

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

This package exports subs that let you write subtests.

=head1 SYNOPSIS

There are 2 types of subtests, buffered and streamed. Streamed subtests mimick
subtest from L<Test::More> in that they render all events as soon as they are
produced. Buffered subtests wait until the subtest completes before rendering
any results.

The main difference is that streamed subtests are unreadable when combined with
concurrency. Buffered subtests look fine with any number of concurrent threads
and processes.

=head2 STREAMED

The exported subnames are very verbose, if you are only going to use one it can
be helpful to alias it to a shorter name.

    use Test::Stream;
    use Test::Stream::Subtest 'subtest_streamed=subtest';

    subtest my_test => sub {
        ok(1, "subtest event A");
        ok(1, "subtest event B");
    };

This will produce output like this:

    # Subtest: my_test
        ok 1 - subtest event A
        ok 2 - subtest event B
        1..2
    ok 1 - Subtest: my_test

=head2 BUFFERED

The exported subnames are very verbose, if you are only going to use one it can
be helpful to alias it to a shorter name.

    use Test::Stream;
    use Test::Stream::Subtest 'subtest_buffered=subtest';

    subtest my_test => sub {
        ok(1, "subtest event A");
        ok(1, "subtest event B");
    };

This will produce output like this:

    ok 1 - Subtest: my_test {
        ok 1 - subtest event A
        ok 2 - subtest event B
        1..2
    }

=head2 BOTH

    use Test::Stream;
    use Test::Stream::Subtest qw/subtest_streamed subtest_buffered/;

    subtest_streamed my_streamed_test => sub {
        ok(1, "subtest event A");
        ok(1, "subtest event B");
    };

    subtest_buffered my_buffered_test => sub {
        ok(1, "subtest event A");
        ok(1, "subtest event B");
    };

This will produce the following output:

    # Subtest: my_test
        ok 1 - subtest event A
        ok 2 - subtest event B
        1..2
    ok 1 - Subtest: my_test

    ok 2 - Subtest: my_test {
        ok 1 - subtest event A
        ok 2 - subtest event B
        1..2
    }

=head1 IMPORTANT NOTE

You can use C<bail_out> or C<skip_all> in a subtest, but not in a BEGIN block
or use statement. This is due to the way flow control works within a begin
block. This is not normally an issue, but can happen in rare conditions using
eval, or script files as subtests.

=head1 EXPORTS

=over 4

=item subtest_streamed $name => $sub

=item subtest_streamed($name, $sub, @args)

Run subtest coderef, stream events as they happen.

=item subtest_buffered $name => $sub

=item subtest_buffered($name, $sub, @args)

Run subtest coderef, render events all at once when subtest is complete.

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
