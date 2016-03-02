# NAME

Test2::Tools::AsyncSubtest - Tools for writing async subtests.

# DESCRIPTION

These are tools for writing async subtests. Async subtests are subtests which
can be started and stashed so that they can continue to recieve events while
other events are also being generated.

# SYNOPSYS

    use Test2::Bundle::Extended;
    use Test2::Tools::AsyncSubtest;

    my $ast1 = async_subtest local => sub {
        ok(1, "Inside subtest");
    };

    my $ast2 = fork_subtest child => sub {
        ok(1, "Inside subtest in another process");
    };

    my $ast3 = thread_subtest thread => sub {
        ok(1, "Inside subtest in a thread");
    };

    # You must call finish on the subtests you create. Finish will wait/join on
    # any child processes and threads.
    $ast1->finish;
    $ast2->finish;
    $ast3->finish;

    done_testing;

# EXPORTS

Everything is exported by default.

- $ast = async\_subtest $name
- $ast = async\_subtest $name => sub { ... }

    Create an async subtest. Run the codeblock if it is provided.

- $ast = fork\_subtest $name => sub { ... }

    Create an async subtest. Run the codeblock in a forked process.

- $ast = thread\_subtest $name => sub { ... }

    Create an async subtest. Run the codeblock in a thread.

# NOTES

- Async Subtests are always buffered.

# SOURCE

The source code repository for Test2-AsyncSubtest can be found at
`http://github.com/Test-More/Test2-AsyncSubtest/`.

# MAINTAINERS

- Chad Granum <exodist@cpan.org>

# AUTHORS

- Chad Granum <exodist@cpan.org>

# COPYRIGHT

Copyright 2015 Chad Granum <exodist7@gmail.com>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://dev.perl.org/licenses/`
