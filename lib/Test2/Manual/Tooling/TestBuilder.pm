package Test2::Manual::Tooling::TestBuilder;

our $VERSION = '1.302220';

1;

__END__

=head1 NAME

Test2::Manual::Tooling::TestBuilder - This section maps Test::Builder methods
to Test2 concepts.

=head1 DESCRIPTION

With Test::Builder tools were encouraged to use methods on the Test::Builder
singleton object. Test2 has a different approach, every tool should get a new
L<Test2::API::Context> object, and call methods on that. This document maps
several concepts from Test::Builder to Test2.

=head1 CONTEXT

First thing to do, stop using the Test::Builder singleton, in fact stop using
or even loading Test::Builder. Instead of Test::Builder each tool you write
should follow this template:

    use Test2::API qw/context/;

    sub my_tool {
        my $ctx  = context();

        ... do work ...

        $ctx->ok(1, "a passing assertion");

        $ctx->release;

        return $whatever;
    }

The original Test::Builder style was this:

    use Test::Builder;
    my $tb = Test::Builder->new; # gets the singleton

    sub my_tool {
        ... do work ...

        $tb->ok(1, "a passing assertion");

        return $whatever;
    }

=head1 TEST BUILDER METHODS

=over 4

=item $tb->BAIL_OUT($reason)

The context object has a 'bail' method:

    $ctx->bail($reason)

=item $tb->diag($string)

=item $tb->note($string)

The context object has diag and note methods:

    $ctx->diag($string);
    $ctx->note($string);

=item $tb->done_testing

The context object has a done_testing method:

    $ctx->done_testing;

Unlike the Test::Builder version, no arguments are allowed.

=item $tb->like

=item $tb->unlike

These are not part of context, instead look at L<Test2::Compare> and
L<Test2::Tools::Compare>.

=item $tb->ok($bool, $name)

    # Preferred
    $ctx->pass($name);
    $ctx->fail($name, @diag);

    # Discouraged, but supported:
    $ctx->ok($bool, $name, \@failure_diags)

=item $tb->subtest

use the C<Test2::API::run_subtest()> function instead. See L<Test2::API> for documentation.

=item $tb->todo_start

=item $tb->todo_end

See L<Test2::Tools::Basic/"skip($why)">, and L<Test2::Todo> instead.

=item $tb->output, $tb->failure_output, and $tb->todo_output

These are handled via formatters now. See L<Test2::Formatter> and
L<Test2::Formatter::TAP>.

=back

=head1 LEVEL

L<Test::Builder> had the C<$Test::Builder::Level> variable that you could
modify in order to set the stack depth. This was useful if you needed to nest
tools and wanted to make sure your file and line number were correct. It was
also frustrating and prone to errors. Some people never even discovered the
level variable and always had incorrect line numbers when their tools would
fail.

B<Note:> C<$Test::Builder::Level> is only defined when L<Test::Builder> is
loaded. If you are writing pure Test2 code, do not use it - use the context
system described below instead.

=head2 The Test2 way: context

L<Test2> uses the context system, which solves the problem a better way. The
top-most tool gets a context, and holds on to it until it is done. Any tool
nested under the first will find and use the original context instead of
generating a new one. This means the level problem is solved for free, no
variables to mess with.

Here is a complete example. Suppose you write a helper that wraps an existing
test tool:

    use Test2::API qw/context/;
    use Test2::Tools::Compare qw/is/;

    sub is_json {
        my ($got_json, $expected, $name) = @_;
        my $ctx = context();      # captures caller's file and line
        my $got = decode_json($got_json);
        is($got, $expected, $name);  # finds $ctx, reports caller's location
        $ctx->release;
    }

When C<is()> is called inside C<is_json()>, it calls C<context()> internally.
Because a context already exists (the one created in C<is_json()>), it reuses
it. This means any failure is reported at the line that called C<is_json()>,
not the line inside it. No level adjustment needed.

You can nest this as deep as you like - only the outermost C<context()> call
determines the reported file and line.

=head2 Edge case: level parameter

If you call C<context()> from inside a callback or wrapper where the context
must point to a frame higher than the direct caller, use the C<level>
parameter:

    sub third_party_wrapper {
        my $sub = shift;
        $sub->();
    }

    third_party_wrapper(sub {
        my $ctx = context(level => 1);  # skip this anonymous sub
        $ctx->ok(1, "reported at third_party_wrapper's caller");
        $ctx->release;
    });

See L<Test2::API/context> for the full list of parameters.

=head2 Legacy compatibility

L<Test2> is also smart enough to honor C<$Test::Builder::Level> if it is set,
but this requires L<Test::Builder> to be loaded. For new code, use
C<context()> instead.

=head1 TODO

L<Test::Builder> used the C<$TODO> package variable to set the TODO state. This
was confusing, and easy to get wrong. See L<Test2::Tools::Todo> for the modern
way to accomplish a TODO state.

=head1 SEE ALSO

L<Test2::Manual> - Primary index of the manual.

=head1 SOURCE

The source code repository for Test2-Manual can be found at
F<https://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
