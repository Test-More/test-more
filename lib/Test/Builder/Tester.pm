package Test::Builder::Tester;

use strict;
our $VERSION = '1.301001_006';

use Test::Builder 0.98;
use Symbol;
use Carp;

=head1 NAME

Test::Builder::Tester - *DEPRECATED* test testsuites that have been built with
Test::Builder

=head1 DEPRECATED

B<This module is deprecated.> Please see L<Test::Tester2> for a
better alternative that does not involve dealing with TAP/string output.

=head1 SYNOPSIS

    use Test::Builder::Tester tests => 1;
    use Test::More;

    test_out("not ok 1 - foo");
    test_fail(+1);
    fail("foo");
    test_test("fail works");

=head1 DESCRIPTION

A module that helps you test testing modules that are built with
L<Test::Builder>.

The testing system is designed to be used by performing a three step
process for each test you wish to test.  This process starts with using
C<test_out> and C<test_err> in advance to declare what the testsuite you
are testing will output with L<Test::Builder> to stdout and stderr.

You then can run the test(s) from your test suite that call
L<Test::Builder>.  At this point the output of L<Test::Builder> is
safely captured by L<Test::Builder::Tester> rather than being
interpreted as real test output.

The final stage is to call C<test_test> that will simply compare what you
predeclared to what L<Test::Builder> actually outputted, and report the
results back with a "ok" or "not ok" (with debugging) to the normal
output.

=cut

####
# set up testing
####

#my $t = Test::Builder->new;

###
# make us an exporter
###

use Test::Builder::Provider;

provides qw(test_out test_err test_fail test_diag test_test line_num);

sub before_import {
    my $class = shift;
    my ($args) = @_;

    my $caller = caller;

    warn __PACKAGE__ . " is deprecated!\n" if builder()->modern;

    builder()->exported_to($caller);
    builder()->plan(@$args);

    my @imports = ();
    foreach my $idx ( 0 .. @$args ) {
        if( $args->[$idx] && $args->[$idx] eq 'import' ) {
            @imports = @{ $args->[ $idx + 1 ] };
            last;
        }
    }

    @$args = @imports;
}

###
# set up file handles
###

# create some private file handles
my $output_handle = gensym;
my $error_handle  = gensym;

# and tie them to this package
my $out = tie *$output_handle, "Test::Builder::Tester::Tie", "STDOUT";
my $err = tie *$error_handle,  "Test::Builder::Tester::Tie", "STDERR";

####
# exported functions
####

# for remembering that we're testing and where we're testing at
my $testing = 0;
my $testing_num;
my $original_is_passing;

my $original_stream;

# remembering where the file handles were originally connected
my $original_output_handle;
my $original_failure_handle;
my $original_todo_handle;

my $original_harness_env;

# function that starts testing and redirects the filehandles for now
sub _start_testing {
    # even if we're running under Test::Harness pretend we're not
    # for now.  This needed so Test::Builder doesn't add extra spaces
    $original_harness_env = $ENV{HARNESS_ACTIVE} || 0;
    $ENV{HARNESS_ACTIVE} = 0;

    # remember what the handles were set to
    $original_output_handle  = builder()->output();
    $original_failure_handle = builder()->failure_output();
    $original_todo_handle    = builder()->todo_output();

    # switch out to our own handles
    builder()->output($output_handle);
    builder()->failure_output($error_handle);
    builder()->todo_output($output_handle);

    # clear the expected list
    $out->reset();
    $err->reset();

    # remember that we're testing
    $testing     = 1;
    $testing_num = builder()->current_test;
    builder()->current_test(0);
    $original_is_passing  = builder()->is_passing;
    builder()->is_passing(1);

    # look, we shouldn't do the ending stuff
    builder()->no_ending(1);
}

=head2 Functions

These are the six methods that are exported as default.

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
been called, all further output from L<Test::Builder> will be
captured by L<Test::Builder::Tester>.  This means that you will not
be able perform further tests to the normal output in the normal way
until you call C<test_test> (well, unless you manually meddle with the
output filehandles)

You can also pass regular expressions to C<test_out> and C<test_err>,
which is documented below in L</Testing For Regular Expressions>

=cut

sub test_out {
    # do we need to do any setup?
    _start_testing() unless $testing;

    $out->expect(@_);
}

sub test_err {
    # do we need to do any setup?
    _start_testing() unless $testing;

    $err->expect(@_);
}

=item test_fail

Because the standard failure message that L<Test::Builder> produces
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
    $err->expect("#     Failed test ($filename at line $line)");
}

=item test_diag

As most of the remaining expected output to the error stream will be
created by L<Test::Builder>'s C<diag> function, L<Test::Builder::Tester>
provides a convenience function C<test_diag> that you can use instead of
C<test_err>.

The C<test_diag> function prepends comment hashes and spacing to the
start and newlines to the end of the expected output passed to it and
adds it to the list of expected error output.  So, instead of writing

   test_err("# Couldn't open file");

you can write

   test_diag("Couldn't open file");

Remember that L<Test::Builder>'s diag function will not add newlines to
the end of output and test_diag will. So to check

   Test::Builder->new->diag("foo\n","bar\n");

You would do

  test_diag("foo","bar")

without the newlines.

You can also pass regular expressions to C<test_diag>, which is
documented below in L</Testing For Regular Expressions>

=cut

sub test_diag {
    # do we need to do any setup?
    _start_testing() unless $testing;

    # expect the same thing, but prepended with "#     "
    local $_;
    $err->expect( map {
            [ "# ",
              ref eq "ARRAY"     ? @{ $_ } :
              ref || m,^/(.*)/$, ? $_ :
              "$_\n"
            ]
        } @_
    )
}

=item test_test

Actually performs the output check testing the tests, comparing the
data (with C<eq>) that we have captured from L<Test::Builder> against
what was declared with C<test_out> and C<test_err>.

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
the original filehandles that L<Test::Builder> was connected to
(probably STDOUT and STDERR,) meaning any further tests you run
will function normally and cause success/errors for L<Test::Harness>.

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

    # okay, reconnect the test suite back to the saved handles
    builder()->output($original_output_handle);
    builder()->failure_output($original_failure_handle);
    builder()->todo_output($original_todo_handle);

    # restore the test no, etc, back to the original point
    builder()->current_test($testing_num);
    $testing = 0;
    builder()->is_passing($original_is_passing);

    # re-enable the original setting of the harness
    $ENV{HARNESS_ACTIVE} = $original_harness_env;

    my $out_complaint = $out->complaint;
    my $err_complaint = $err->complaint;

    # check the output we've stashed
    unless( builder()->ok( ( $args{skip_out} || !defined($out_complaint) ) &&
                           ( $args{skip_err} || !defined($err_complaint) ), $mess ) 
    ) {
        # print out the diagnostic information about why this
        # test failed

        local $_;

        builder()->diag( $out_complaint )
          unless $args{skip_out} || !defined $out_complaint;

        builder()->diag( $err_complaint )
          unless $args{skip_err} || !defined $err_complaint;
    }
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

In addition to the six exported functions there exists one
function that can only be accessed with a fully qualified function
call.

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
L<Text::Builder::Tester::Color> module like so:

   perl -Mlib=Text::Builder::Tester::Color test.t

Or by including the L<Test::Builder::Tester::Color> module directly in
the PERL5LIB.

=item green_string

Returns the current ANSI escape sequences for the I<green> color.
When C<color> is not enabled this is always returns the empty string.

You can set a new string to be used by passing an argument.  By
default, or if you set the string to an undefined value, this will
attempt to use Term::ANSIColor to render black text on a green background
(In this situation if you do not have Term::ANSIColor installed
then the empty string will be returned.)

=item red_string

Returns the current ANSI escape sequences for the I<red> color.
When C<color> is not enabled this is always returns the empty string.

You can set a new string to be used by passing an argument.  By
default, or if you set the string to an undefined value, this will
attempt to use Term::ANSIColor to render black text on a red background
(In this situation if you do not have Term::ANSIColor installed
then the empty string will be returned.)

=item reset_string

Returns the current ANSI escape sequences for the resetting the
terminal to the default color.  When C<color> is not enabled this
always returns the empty string.

You can set a new string to be used by passing an argument.  By
default, or if you set the string to an undefined value, this will
attempt to use Term::ANSIColor to reset the terminal to default
(In this situation if you do not have Term::ANSIColor installed
then the empty string will be returned.)

=cut

my $color;

sub color {
    $color = shift if @_;
    $color;
}

my $green_string;
sub green_string {
    $green_string = shift if @_;
    return "" unless color();
    return $green_string if defined $green_string;

    return eval {
        require Term::ANSIColor;
        Term::ANSIColor::color("black") . Term::ANSIColor::color("on_green")
    } || ""
}

my $red_string;
sub red_string {
    $red_string = shift if @_;
    return "" unless color();
    return $red_string if defined $red_string;

    return eval {
        require Term::ANSIColor;
        Term::ANSIColor::color("black") . Term::ANSIColor::color("on_red")
    } || ""
}

my $reset_string;
sub reset_string {
    $reset_string = shift if @_;
    return "" unless color();
    return $reset_string if defined $reset_string;

    return eval {
        require Term::ANSIColor;
        Term::ANSIColor::color("reset")
    } || ""
}

=back

=head2 Testing For Regular Expressions

As well as checking for simple strings, you can also check for
regular expressions when using C<test_out>, C<test_err> or
C<test_diag>.

    test_out('/not ok [0-9]+ - (.*)\n/');
    test_fail(+2);
    test_diag(qr/fo+\n/);
    ok(0,"oh no");
    diag("foo");
    test_test();

The regular expressions can be passed in one of two forms;  A
standard regular expression reference of the form C<qr/foo/> or
as a plain old string starting and ending with C</>, i.e. C<"/foo/">
(which allow you to write tests compatible with ancient versions of Perl
that don't support C<qr//>.)

Each plain string argument to C<test_out>, C<test_err> or
C<test_diag> has a newline automatically added.  If you want
to test a single line with a combination of strings and regular
expressions (allowing Test::Builder::Tester to give better colored
output than using a single regular expression should the test fail)
you can use an array reference to indicate nothing within it should
have a newline appended.

   # expect two lines of diag
   test_diag(
     ["The value ", qr/[0-9]+/, " is too high.","\n"],
     "Expected a value below 10.",
   );

=head1 BUGS

Calls C<< Test::Builder->no_ending >> turning off the ending tests.
This is needed as otherwise it will trip out because we've run more
tests than we strictly should have and it'll register any failures we
had that we were testing for as real failures.

The color function doesn't work unless L<Term::ANSIColor> is
compatible with your terminal.

See F<http://rt.cpan.org> to report and view bugs.

=head1 AUTHOR

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004,
2014.

Some code taken from L<Test::More> and L<Test::Catch>, written by
Michael G Schwern E<lt>schwern@pobox.comE<gt>.  Hence, those parts
Copyright Micheal G Schwern 2001.  Used and distributed with
permission.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 NOTES

Thanks to Richard Clamp E<lt>richardc@unixbeard.netE<gt> for letting
me use his testing system to try this module out on.

=head1 SEE ALSO

L<Test::Builder>, L<Test::Builder::Tester::Color>, L<Test::More>.

=cut

1;

####################################################################
# Helper class that is used to remember expected and received data

package Test::Builder::Tester::Tie;

##
# add line(s) to be expected

sub expect {
    my $self = shift;
    push @{ $self->{wanted} },
        map { $self->_translate_Failed_check($_) }
        map { $self->_account_for_subtest($_) }
        $self->_group_checks(
            map { $self->_flatten_and_add_return($_) } @_
        );
}

# takes a list of string and regex checks and returns
# a list with all adjacent string checks concatinated into
# single checks.  This is so we look in the string checks
# for the very old school failed test string declarations 
sub _group_checks {
    my $self = shift;
    return unless @_;
    my @r = shift @_;
    my $regex = ref $r[0] || $r[0] =~ m'\A/.*/\z';
    foreach (@_) {
        if (ref || m'\A/.*/\z') {
            push @r, $_;
            $regex = 1;
            next;
        }
        if ($regex) {
            push @r, $_;
            undef $regex;
        } else {
            $r[-1] .= $_;
        }
    }
    return @r;
}

sub _flatten_and_add_return {
    my $self = shift;
    my $check = shift;

    if (ref($check) eq "ARRAY") {
        return @{ $check };
    }

    return $check if ref $check || $check =~ m'\A/.*/\z';
    return "$check\n";
}

# TODO: This should probably return a two element list, the indent and the check
# when it's passed a regex, but that's a change in behavior, so...don't fix now
sub _account_for_subtest {
    my( $self, $check ) = @_;

    my $builder = Test::Builder::Tester->builder();
    # Since we ship with Test::Builder, calling a private method is safe...ish.
    return ref($check) ? $check : ($builder->depth ? '    ' x $builder->depth : '') . $check;
}

sub _translate_Failed_check {
    my( $self, $check ) = @_;

    my @ret = ($check);
    while ( $ret[0] =~ /\A(.*)#     (Failed .*test) \((.*?) at line (\d+)\)\n?(.*)\z/s ) {
        splice @ret, 0, 1, $1, "/#\\s+\Q$2\E.*?\\n?.*?\Qat $3\E line \Q$4\E.*\\n?/", $5;
    }

    return @ret;
}

##
##
# a complaint message about the inputs not matching (to be
# used for debugging messages)

sub complaint {
    my $self   = shift;
    my $type   = $self->type;
    my $got    = $self->got;
    my @checks = (@{ $self->wanted }, "");

    my $got_output = "";
    my $wanted_output = "";

    # the colors
    my $red   = Test::Builder::Tester::red_string();
    my $green = Test::Builder::Tester::green_string();
    my $reset = Test::Builder::Tester::reset_string();

    my $failing;
    foreach my $check (@checks) {

        # are we failing?  If we are, just convert each
        # check into a failing block
        if ($failing) {
            my $str = "$check";
            $str =~ s/\n/$reset\n$red/g;
            $wanted_output .= $red . $str . $reset;

            next;
        }

        # are we testing against a regex?
        my $potential_regex = $check;
        if (ref $potential_regex || $potential_regex =~ s,^/(.*)/$,$1,) {

            # check the regex matches
            my $matched;
            unless ($got =~ s/\A($potential_regex)//) {
                $failing = 1;
                $got =~ s/\n/$reset\n$red/g;
                $got_output .= $red . $got . $reset;
                redo;
            }
            $matched = $1;

            # markup what we matched and add it to the output
            $matched =~ s/\n/$reset\n$green/g;
            $got_output .= $green . $matched . $reset;
            $wanted_output .= $green . $check . $reset;

            next;
        }

        # we're testing against a plain old string.
        my $index = 0;
        while (1) {

            # did we run out of "got"?
            if ($index > length($got)) {
                $failing = 1;

                # append the "matched" part to both
                $got =~ s/\n/$reset\n$green/g;
                $got = $green. $got . $reset;
                $got_output .= $got;
                $wanted_output .= $got;

                # append the rest of "not matched" stuff to expected
                my $not_matched = substr($check,$index);
                $not_matched =~ s/\n/$reset\n$red/g;
                $wanted_output .= $red . $not_matched . $reset;

                last;
            }

            # did we run out of text in this check
            # (in which case we move onto the next one)
            if ($index == length($check)) {

                # append the "matched" part to both
                my $matched = substr($got,0,$index,"");
                $matched =~ s/\n/$reset\n$green/g;
                $matched = $green. $matched . $reset;
                $got_output .= $matched;
                $wanted_output .= $matched;

                last;
            }

            # did we have a non matching character?
            if (substr($got, $index, 1) ne substr($check, $index, 1)) {
                $failing = 1;

                # append the "matched" part to both
                my $matched = substr($got,0,$index,"");
                $matched =~ s/\n/$reset\n$green/g;
                $matched = $green. $matched . $reset;
                $got_output .= $matched;
                $wanted_output .= $matched;

                # append the not matched part
                $got =~ s/\n/$reset\n$red/g;
                $got_output .= $red. $got . $reset;

                # append the rest of "not matched" stuff to expected
                my $check_not_matched = substr($check,$index);
                $check_not_matched =~ s/\n/$reset\n$red/g;
                $wanted_output .= $red . $check_not_matched . $reset;

                last;
            }

            $index++;
        }
    }

    unless ($failing) {
        return unless length $got;
        $got =~ s/\n/$reset\n$red/g;
        $got_output .= $red. $got . $reset;
    }

    return "$type is:\n" . "$got_output\nnot:\n$wanted_output\nas expected";
}

sub check {
    my $self = shift;
    return !defined $self->complaint;
}

##
# forget all expected and got data

sub reset {
    my $self = shift;
    %$self = (
        type   => $self->{type},
        got    => '',
        wanted => [],
    );
}

sub got {
    my $self = shift;
    return $self->{got};
}

sub wanted {
    my $self = shift;
    return $self->{wanted};
}

sub type {
    my $self = shift;
    return $self->{type};
}

###
# tie interface
###

sub PRINT {
    my $self = shift;
    $self->{got} .= join '', @_;
}

sub TIEHANDLE {
    my( $class, $type ) = @_;

    my $self = bless { type => $type }, $class;

    $self->reset;

    return $self;
}

sub READ     { }
sub READLINE { }
sub GETC     { }
sub FILENO   { }

1;
