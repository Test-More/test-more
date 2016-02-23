# NAME

Test2::Tools::AsyncSubtest - Tools for writing async subtests.

# DESCRIPTION

These are tools for writing async subtests. Async subtests are subtests which
can be started and stashed so that they can continue to recieve events while
other events are also being generated.

# SYNOPSYS

    use Test2::Bundle::Extended;
    use Test2::Tools::AsyncSubtest;

    my $ast = subtest_start('ast');

    subtest_run $ast => sub {
        ok(1, "not concurrent A");
    };

    ok(1, "Something else");

    subtest_run $ast => sub {
        ok(1, "not concurrent B");
    };

    ok(1, "Something else");

    subtest_finish($ast);

    done_testing;

# EXPORTS

Everything is exported by default.

- $ast = subtest\_start($name)

    Create a new async subtest. `$ast` will be an instance of
    [Test2::AsyncSubtest](https://metacpan.org/pod/Test2::AsyncSubtest).

- $passing = subtest\_run($ast, sub { ... })

    Run the provided codeblock from inside the async subtest. This can be called
    any number of times, and can be called from any process or thread spawned after
    `$ast` was created.

- $passing = subtest\_finish($ast)

    This will finish the async subtest and send the final [Test2::Event::Subtest](https://metacpan.org/pod/Test2::Event::Subtest)
    event to the current hub.

    **Note:** This must be called in the thread/process that created the Async
    Subtest.

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
