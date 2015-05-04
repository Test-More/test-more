package Test::Stream::Subtest;
use strict;
use warnings;

use Test::Stream::Exporter;
default_exports qw/subtest/;
Test::Stream::Exporter->cleanup;

use Test::Stream::Context qw/context/;
use Scalar::Util qw/reftype blessed/;
use Test::Stream::Util qw/try/;
use Test::Stream::Carp qw/confess/;
use Test::Stream::Threads;

use Test::Stream::Block;

sub subtest {
    my ($name, $code, @args) = @_;

    my $ctx = context();

    my $block;
    if (blessed($code) && $code->isa('Test::Stream::Block')) {
        $block = $code;
    }
    elsif (ref $code && 'CODE' eq reftype($code)) {
        $block = Test::Stream::Block->new(
            name    => $name,
            coderef => $code,
            caller  => [caller(0)],
        );
    }
    else {
        $ctx->throw("subtest()'s second argument must be a code ref")
            unless $code && 'CODE' eq reftype($code);
    }

    $ctx->note("Subtest: $name")
        unless $ctx->hub->subtest_buffering;

    my $st = $ctx->_subtest_start($name);

    my $pid = $$;
    my $tid = get_tid();

    my ($succ, $err) = try {
        TEST_HUB_SUBTEST: {
            no warnings 'once';
            local $Test::Builder::Level = 1;
            $block->run(@args);
        }

        return if $st->{early_return};
        return unless $$ == $pid && get_tid() == $tid;

        my $hub = $ctx->hub;
        $hub->ipc_cull();

        $ctx->set;
        $ctx->done_testing unless $hub->plan || $hub->ended;

        require Test::Stream::ExitMagic;
        {
            local $? = 0;
            Test::Stream::ExitMagic->new->do_magic($hub, $ctx->snapshot);
        }
    };

    my $er = $st->{early_return};
    if (!$succ) {
        # Early return is not a *real* exception.
        if ($er && $er == $err) {
            $succ = 1;
            $err = undef;
        }
        else {
            $st->{exception} = $err;
        }
    }

    if ($$ != $pid || $tid != get_tid()) {
        if ($succ) {
            my $thing = $$ == $pid ? "thread" : "process";
            $err = <<"            EOT";
New $thing was started inside of the subtest '$name', but the $thing did not
terminate before the end of the subtest subroutine. All threads and child
processes started inside a subtest subroutine must complete inside the subtest
subroutine.
            EOT
        }

        if ($ctx->hub->concurrency_driver) {
            $ctx->send_event( 'Exception', error => $err );
        }
        else {
            print STDERR $err;
        }

        # If we are in a new thread we exit the thread, if a process we exit
        # the process.
        if ($$ == $pid) {
            thread->exit();
        }
        else {
            exit 255;
        }
    }

    my $st_check = $ctx->_subtest_stop($name);
    confess "Subtest mismatch!" unless $st == $st_check;

    $ctx->bail($st->{early_return}->reason) if $er && $er->isa('Test::Stream::Event::Bail');

    my $e = $ctx->send_event(
        'Subtest',
        name         => $st->{name},
        state        => $st->{state},
        events       => $st->{events},
        exception    => $st->{exception},
        early_return => $st->{early_return},
        buffer       => $st->{buffer},
        spec         => $st->{spec},
    );

    die $err unless $succ;

    return $e->effective_pass;
}

1;

__END__

=pod

=encoding UTF-8

=head1 Name

Test::Stream::Subtest - Encapsulate subtest start, run, and finish.

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


=head1 Synopsys

    use Test::More;

    subtest 'An example subtest' => sub {
        pass("This is a subtest");
        pass("So is this");
    };

    done_testing;

=head1 DESCRIPTION

C<< subtest name => sub { ... } >> runs the code as its own little test with
its own plan and its own result.  The main test counts this as a single test
using the result of the whole subtest to determine if its ok or not ok.

=head1 COMPLETE EXAMPLE

  use Test::More tests => 3;

  pass("First test");

  subtest 'An example subtest' => sub {
      plan tests => 2;

      pass("This is a subtest");
      pass("So is this");
  };

  pass("Third test");

This would produce.

  1..3
  ok 1 - First test
      # Subtest: An example subtest
      1..2
      ok 1 - This is a subtest
      ok 2 - So is this
  ok 2 - An example subtest
  ok 3 - Third test

=head1 SKIPPING ALL TESTS IN A SUBTEST

A subtest may call C<skip_all>.  No tests will be run, but the subtest is
considered a skip.

  subtest 'skippy' => sub {
      plan skip_all => 'cuz I said so';
      pass('this test will never be run');
  };

Returns true if the subtest passed, false otherwise.

=head2 SKIPPING ALL IN A BEGIN BLOCK

Sometimes you want to run a file as a subtest:

    subtest foo => sub { do 'foo.pl' };

where foo.pl;

    use Test::More skip_all => "won't work";

This will work fine, but will issue a warning. The issue is that the normal
flow control method will not work inside a BEGIN block. The C<use Test::More>
statement is run in a BEGIN block. As a result an exception is thrown instead
of the normal flow control. In most cases this works fine.

A case like this however will have issues:

    subtest foo => sub {
        do 'foo.pl'; # Will issue a skip_all

        # You would expect the subtest to stop, but the 'do' captures the
        # exception, as a result the following statement does execute.

        ok(0, "blah");
    };

You can work around this by cheking the return from C<do>, along with C<$@>, or
you can alter foo.pl so that it does this:

    use Test::More;
    plan skip_all => 'broken';

When the plan is issues outside of the BEGIN block it works just fine.

=head1 SUBTEST PLANNING

Due to how subtests work, you may omit a plan if you desire.  This adds an
implicit C<done_testing()> to the end of your subtest.  The following two
subtests are equivalent:

  subtest 'subtest with implicit done_testing()' => sub {
      ok 1, 'subtests with an implicit done testing should work';
      ok 1, '... and support more than one test';
      ok 1, '... no matter how many tests are run';
  };

  subtest 'subtest with explicit done_testing()' => sub {
      ok 1, 'subtests with an explicit done testing should work';
      ok 1, '... and support more than one test';
      ok 1, '... no matter how many tests are run';
      done_testing();
  };

=head1 SUBTESTS AND CONCURRENCY

=head2 STARTING A SUBTEST IN A NEW PROCESS

This works fine:

    use Test::More;
    use Test::Stream 'concurrency';

    my $pid = fork();
    if (!$pid) {
        subtest foo => sub {
            ok(1, "inside foo");
        };
        exit 0;
    }
    waitpid($pid, 0);

    done_testing;

Per usual, always observe proper forking practices, be sure to exit your
process when you are done with it.

=head2 STARTING A SUBTEST IN A NEW THREAD

This works fine:

    use threads;
    use Test::More;

    my $thr = threads->create(sub {
        subtest foo => sub {
            ok(1, "inside foo");
        };
    };

    $thr->join;

    done_testing;

Per usual, always observe proper threading practices, call C<join()> on your
thread.

=head2 STARTING A NEW PROCESS INSIDE A SUBTEST

This works fine:

    use Test::More;
    use Test::Stream 'concurrency';

    subtest foo => sub {
        my $pid = fork();
        if (!$pid) {
            ok(1, "inside child $$");
            exit 0;
        }

        ok(1, "In parent $$");

        waitpid($pid, 0);
    };

    done_testing;

If you start a new process inside a subtest, you B<MUST> end the process
B<BEFORE> the subtest completes. This means calling C<exit()> before the
subtest subroutine ends in the child process. You B<MUST> also wait on the
child process C<BEFORE> the subroutine ends in the parent.

If you forget to end the new process or thread in the child, the subtest will
end it for you, and throw an exception in the parent. If you fail to wait or
join in the parent, an exception will be thrown for any event that is recieved
after the subtest ends.

=head2 STARTING A NEW THREAD INSIDE A SUBTEST

This works fine:

    use threads;
    use Test::More;

    subtest foo => sub {
        my $thr = threads->create(sub {
            ok(1, "inside child $$");
            exit 0;
        });

        ok(1, "In parent $$");
        $thr->join;
    };

    done_testing;

You B<MUST> join all the threads created in the subtest B<BEFORE> the subtest
subroutine ends.

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
