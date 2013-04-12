package Test::Builder::Tester;

use TB2::Mouse;
BEGIN {
    our $VERSION = "1.24_006";

    extends 'Test::Builder::Module';
    with 'TB2::CanLoad';

    our @EXPORT = qw(test_out test_err test_fail test_diag test_test line_num change_formatter);
    our @EXPORT_OK = qw(color change_formatter_class);
}

use Test::Builder;
use Carp;


####
# exported functions
####


=head1 NAME

Test::Builder::Tester - test modules built with Test::Builder

=head1 SYNOPSIS

    use Test::Builder::Tester tests => 1;
    use Test::More;

    test_out("not ok 1 - foo");
    test_fail(+1);
    fail("foo");
    test_test("fail works");

=head1 DESCRIPTION

Because testing formatted TAP is unstable, this module is
B<DISCOURAGED>.  It is recommended you use L<Test::Tester> or
L<TB2::Tester> and test events directly before they are formatted.

A module that helps you test testing modules that are built with
B<Test::Builder>.

The testing system is designed to be used by performing a three step
process for each test you wish to test.  This process starts with using
C<test_out> and C<test_err> in advance to declare what the testsuite you
are testing will output with B<Test::Builder> to stdout and stderr.

You then can run the test(s) from your test suite that call
B<Test::Builder>.  At this point the output of B<Test::Builder> is
safely captured by B<Test::Builder::Tester> rather than being
interpreted as real test output.

The final stage is to call C<test_test> that will simply compare what you
predeclared to what B<Test::Builder> actually outputted, and report the
results back with a "ok" or "not ok" (with debugging) to the normal
output.

=cut

####
# set up testing
####

my $t = Test::Builder->new;

# for remembering that we're testing
my $testing = 0;

# Store the normal TestState
my $original_state;

# Store the state of the harness
my $original_harness_env;

# Store the streamer used for capturing output
use Test::Builder::Tester::Streamer;
my $streamer = Test::Builder::Tester::Streamer->new;

# For testing ourself
sub _streamer { return $streamer }

# function that starts testing and redirects the filehandles for now
sub _start_testing {
    # even if we're running under Test::Harness pretend we're not
    # for now.  This needed so Test::Builder doesn't add extra spaces
    $original_harness_env = $ENV{HARNESS_ACTIVE} || 0;
    $ENV{HARNESS_ACTIVE} = 0;

    # Store the default TestState
    $original_state = $t->test_state;

    my $formatter = _make_formatter();

    # Make a detached TestState
    my $state = $original_state->create(
        formatters      => [],

        # Preserve existing handlers
        early_handlers  => $original_state->early_handlers,
        late_handlers   => $original_state->late_handlers,
    );

    # To retain compatibility with old behaviors...
    # start testing but don't let the formatter see it
    $state->post_event( TB2::Event::TestStart->new );
    # use the original plan
    $state->post_event( $original_state->history->plan )
      if $original_state->history->plan;
    $state->add_formatters($formatter);

    # remember that we're testing
    $testing     = 1;

    # Override the state in the builder and for everyone
    $t->{TestState} = $state;
    TB2::TestState->default($state);

    # we shouldn't do the ending stuff
    $t->no_change_exit_code(1);
    $t->no_ending(1);
}

=head2 Functions

=head3 Exported by default

=over 4

=item test_out

=item test_err

Procedures for predeclaring the output that your test suite is
expected to produce until C<test_test> is called.  These procedures
automatically assume that each line terminates with "\n".  So

   test_out("ok 1","ok 2");

is the same as

   test_out("ok 1\nok 2");

which is even the same as

   test_out("ok 1");
   test_out("ok 2");

Once C<test_out> or C<test_err> (or C<test_fail> or C<test_diag>) have
been called, all further output from B<Test::Builder> will be
captured by B<Test::Builder::Tester>.  This means that you will not
be able perform further tests to the normal output in the normal way
until you call C<test_test> (well, unless you manually meddle with the
output filehandles)

=cut

sub test_out {
    # do we need to do any setup?
    _start_testing() unless $testing;

    $streamer->expect("out", @_);
}

sub test_err {
    # do we need to do any setup?
    _start_testing() unless $testing;

    $streamer->expect("err", @_);
}

=item test_fail

Because the standard failure message that B<Test::Builder> produces
whenever a test fails will be a common occurrence in your test error
output, and because it has changed between Test::Builder versions, rather
than forcing you to call C<test_err> with the string all the time like
so

    test_err("# Failed test ($0 at line ".line_num(+1).")");

C<test_fail> exists as a convenience function that can be called
instead.  It takes one argument, the offset from the current line that
the line that causes the fail is on.

    test_fail(+1);

This means that the example in the synopsis could be rewritten
more simply as:

   test_out("not ok 1 - foo");
   test_fail(+1);
   fail("foo");
   test_test("fail works");

=cut

sub test_fail {
    # do we need to do any setup?
    _start_testing() unless $testing;

    # work out what line we should be on
    my( $package, $filename, $line ) = caller;
    $line = $line + ( shift() || 0 );    # prevent warnings

    # expect that on stderr
    $streamer->expect("err", "#     Failed test ($filename at line $line)");
}

=item test_diag

As most of the remaining expected output to the error stream will be
created by Test::Builder's C<diag> function, B<Test::Builder::Tester>
provides a convenience function C<test_diag> that you can use instead of
C<test_err>.

The C<test_diag> function prepends comment hashes and spacing to the
start and newlines to the end of the expected output passed to it and
adds it to the list of expected error output.  So, instead of writing

   test_err("# Couldn't open file");

you can write

   test_diag("Couldn't open file");

Remember that B<Test::Builder>'s diag function will not add newlines to
the end of output and test_diag will. So to check

   Test::Builder->new->diag("foo\n","bar\n");

You would do

  test_diag("foo","bar")

without the newlines.

=cut

sub test_diag {
    # do we need to do any setup?
    _start_testing() unless $testing;

    # expect the same thing, but prepended with "#     "
    $streamer->expect("err", map { "# $_" } @_ );
}

=item test_test

Actually performs the output check testing the tests, comparing the
data (with C<eq>) that we have captured from B<Test::Builder> against
that that was declared with C<test_out> and C<test_err>.

This takes name/value pairs that effect how the test is run.

=over

=item title (synonym 'name', 'label')

The name of the test that will be displayed after the C<ok> or C<not
ok>.

=item skip_out

Setting this to a true value will cause the test to ignore if the
output sent by the test to the output stream does not match that
declared with C<test_out>.

=item skip_err

Setting this to a true value will cause the test to ignore if the
output sent by the test to the error stream does not match that
declared with C<test_err>.

=back

As a convenience, if only one argument is passed then this argument
is assumed to be the name of the test (as in the above examples.)

Once C<test_test> has been run test output will be redirected back to
the original filehandles that B<Test::Builder> was connected to
(probably STDOUT and STDERR,) meaning any further tests you run
will function normally and cause success/errors for B<Test::Harness>.

=cut

sub test_test {
    # decode the arguments as described in the pod
    my $mess;
    my %args;
    if( @_ == 1 ) {
        $mess = shift
    }
    else {
        %args = @_;
        $mess = $args{name} if exists( $args{name} );
        $mess = $args{title} if exists( $args{title} );
        $mess = $args{label} if exists( $args{label} );
    }

    # er, are we testing?
    croak "Not testing.  You must declare output with a test function first."
      unless $testing;

    # restore the original test state
    TB2::TestState->default($original_state);
    $t->{TestState} = $original_state;

    # Switch off testing mode
    $testing = 0;

    # re-enable the original setting of the harness
    $ENV{HARNESS_ACTIVE} = $original_harness_env;

    # check the output we've stashed
    unless( $t->ok( ( $args{skip_out} || $streamer->check("out") ) &&
                    ( $args{skip_err} || $streamer->check("err") ), $mess ) 
    )
    {
        # print out the diagnostic information about why this
        # test failed

        $t->diag( map { "$_\n" } $streamer->complaint("out") )
          unless $args{skip_out} || $streamer->check("out");

        $t->diag( map { "$_\n" } $streamer->complaint("err") )
          unless $args{skip_err} || $streamer->check("err");
    }

    # Clear the streamer
    $streamer->clear;
}

=item line_num

A utility function that returns the line number that the function was
called on.  You can pass it an offset which will be added to the
result.  This is very useful for working out the correct text of
diagnostic functions that contain line numbers.

Essentially this is the same as the C<__LINE__> macro, but the
C<line_num(+3)> idiom is arguably nicer.

=cut

sub line_num {
    my( $package, $filename, $line ) = caller;
    return $line + ( shift() || 0 );    # prevent warnings
}

=back

=head3 Exported on request

These functions can be exported by using a special syntax which comes
from L<Test::Builder::Module>.

    use Test::Builder::Tester import => [@exporter_args];

For example...

    # Import all the usual functions, plus color
    use Test::Builder::Tester import => [':DEFAULT', 'color'];

=over 4

=item color

When C<test_test> is called and the output that your tests generate
does not match that which you declared, C<test_test> will print out
debug information showing the two conflicting versions.  As this
output itself is debug information it can be confusing which part of
the output is from C<test_test> and which was the original output from
your original tests.  Also, it may be hard to spot things like
extraneous whitespace at the end of lines that may cause your test to
fail even though the output looks similar.

To assist you C<test_test> can colour the background of the debug
information to disambiguate the different types of output. The debug
output will have its background coloured green and red.  The green
part represents the text which is the same between the executed and
actual output, the red shows which part differs.

The C<color> function determines if colouring should occur or not.
Passing it a true or false value will enable or disable colouring
respectively, and the function called with no argument will return the
current setting.

To enable colouring from the command line, you can use the
B<Text::Builder::Tester::Color> module like so:

   perl -Mlib=Text::Builder::Tester::Color test.t

Or by including the B<Test::Builder::Tester::Color> module directly in
the PERL5LIB.

=cut

my $color;

sub color {
    $color = shift if @_;
    $color;
}

=item change_formatter_class

    change_formatter_class( $formatter_class );

By default, output will be formatted using the
L<TB2::Foramtter::TAP::TB1> to be compatibile with tests written using
Test::More 0.98.

If your test does not need to be backwards compatible with 0.98, you
can change this.  L<TB2::Formatter::TAP> is the default formatter now
used by Test::More.

=cut

{
    # Use the legacy TAP formatter to keep compatible with 0.98.
    my $formatter_class = 'TB2::Formatter::TAP::TB1';
    sub change_formatter_class {
        $formatter_class = shift;

        return;
    }

    sub _make_formatter {
        __PACKAGE__->load($formatter_class);
        return $formatter_class->new(
            streamer => _streamer()
        );
    }
}

=back

=head1 BUGS

The color function doesn't work unless B<Term::ANSIColor> is
compatible with your terminal.

Bugs (and requests for new features) can be reported to the author
though the CPAN RT system:
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-Builder-Tester>

=head1 AUTHOR

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

Some code taken from B<Test::More> and B<Test::Catch>, written by by
Michael G Schwern E<lt>schwern@pobox.comE<gt>.  Hence, those parts
Copyright Micheal G Schwern 2001.  Used and distributed with
permission.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 NOTES

Thanks to Richard Clamp E<lt>richardc@unixbeard.netE<gt> for letting
me use his testing system to try this module out on.

=head1 SEE ALSO

L<Test::Builder>, L<Test::Builder::Tester::Color>, L<Test::More>.

=cut

1;
