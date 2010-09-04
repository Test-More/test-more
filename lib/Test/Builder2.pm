package Test::Builder2;

use 5.008001;
use Test::Builder2::Mouse;
use Test::Builder2::Types;

use Test::Builder2::Result;
use Test::Builder2::AssertRecord;

use Carp qw(confess);
sub sanity ($) { confess "Assert failed" unless $_[0] };


=head1 NAME

Test::Builder2 - 2nd Generation test library builder

=head1 SYNOPSIS

If you're writing a test library, you should start with
L<Test::Builder2::Module>.

If you're writing a test, you should start with L<Test::Simple>.

=head1 DESCRIPTION

Test::Builder2 is an object for writing testing libraries.  It records
assert results and formats them for output.  It also provides a
central location for test libraries to place behaviors when certain
test events happen, like an assert failing or a new test starting.
Finally, it records the point where the user called an assert allowing
test libraries to freely call asserts inside asserts but still report
failure at a file and line number useful to the user.

The end goal of all this is to allow test authors to write their own
asserts without having to worry about coordination with other test
libraries or formatting.

There is usually a single Test::Builder2 object per test process
coordinating everything.  Results are stored in a single
L<Test::Builder2::History> object and formatting the results with a
single L<Test::Builder2::Formatter>.

Test::Builder2 is very generic and doesn't do a lot of the work you've
probably come to expect a test framework to do.  This reduction of
assumptions increases flexibility and ensures that TB2 can remain the
core of Perl testing for another decade to come.  Extra beahviors are
either farmed out to other objects which can be swapped out for others
with more behavior or placed into roles that can be applied to the TB2
object as desired.


=head2 Mouse

Test::Builder2 is a L<Mouse> object (like Moose, but smaller) to take
advantage of the advances in OO over the last 10 years.  To avoid
dependencies and bugs caused by changes in Mouse, Test::Builder2 ships
and uses its own copy of Mouse called L<Test::Builder2::Mouse>.  All
Mouse classes have L<Test::Builder2::> prepended.

You can take advantage of all the features Mouse has to offer,
including roles and meta stuff.  You are free to use
Test::Builder2::Mouse in your TB2 derived classes or use Mouse
directly.


=head2 METHODS

=head3 history

    my $history = $builder->history;

Contains the Test::Builder2::History object recording results.

=cut

has history_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::History',
);

has history => (
  reader        => 'history',
  writer        => 'set_history',
  isa           => 'Test::Builder2::History',
  builder       => '_build_history',
  lazy          => 1,
);

sub _build_history {
    my $self = shift;
    $self->history_class->singleton;
}


=head3 planned_tests

    my $num_tests = $builder->planned_tests;

Number of tests planned, if at all.

Unlike Test::Builder, TB2 does not assume your test needs a plan.

This may be moved into a role in the future.

=cut

has planned_tests =>
  is            => 'rw',
  isa           => 'Int',
  default       => 0;

=head3 formatter

    my $formatter = $builder->formatter;

A L<Test::Builder2::Formatter> object used to format results for
output.

Defaults to L<Test::Builder2::Formatter::TAP>.

=cut

has formatter_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::Formatter::TAP',
);

has formatter => (
  reader        => 'formatter',
  writer        => 'set_formatter',
  isa           => 'Test::Builder2::Formatter',
  builder       => '_build_formatter',
  lazy          => 1,
);

sub _build_formatter {
    my $self = shift;
    $self->formatter_class->new;
}


=head3 top

=head3 top_stack

  my $top_stack = $tb->top_stack;

Stores the current stack of asserts being run as a
Test::Builder2::AssertStack.

=cut

has top_stack =>
  is            => 'ro',
  isa           => 'Test::Builder2::AssertStack',
  default       => sub {
      require Test::Builder2::AssertStack;
      Test::Builder2::AssertStack->new;
  };


=head3 stream_start

  $tb->stream_start(%options);

Inform the builder that testing is about to begin.  This will allow
the builder to output any necessary headers.

Extension authors are encouraged to put method modifiers around
stream_start().

=cut

sub stream_start {
    my $self = shift;
    my %options = @_;

    %options = $self->set_plan( %options );

    $self->formatter->begin(%options);

    return;
}

=head3 stream_end

  $tb->stream_end(%options);

Inform the Builder that testing is complete.  This will allow the builder to
perform any end of testing checks and actions, such as outputting a plan, and
inform any other objects, such as the formatter.

Extension authors are encouraged to put method modifiers on
stream_end().

=cut

sub stream_end {
    my $self    = shift;
    my %options = @_;

    $self->set_plan( %options );

    $self->formatter->end(%options);
}


=head3 assert_start

  $tb->assert_start;

Called just before a user written test function begins, an assertion.

By default it records the caller at this point in C<< $self->top_stack >>
for the purposes of reporting test file and line numbers properly.

Extension authors are encouraged to put method modifiers on
assert_start()

This will be called when *any* assertion begins.  If you want to
know when the assertion is called from the user's point of view, check
C<< $self->top_stack >>.  It will be empty before and have a single
assert after.

=cut

sub assert_start {
    my $self = shift;

    my $record = Test::Builder2::AssertRecord->new_from_caller(1);
    sanity $record;

    $self->top_stack->push($record);

    return;
}

=head3 assert_end

  $tb->assert_end($result);

Like C<assert_start> but for just after a user written assert function
finishes.

By default it pops C<< $self->top_stack >> and if this is the last
assert in the stack it formats the result.

Extension authors are encouraged to put method modifiers on
assert_end().

This will be called when *any* assertion ends.  If you want to know
when the assertion is complete from the user's point of view, check
C<< $self->top_stack >>.  It will have a single element before and be
empty after.

    # Here's how you'd implement "die on fail", ignoring turning this
    # into a role and applying it to the TB2 object.
    after assert_end => sub {
        my $self = shift;
        my $result = shift;

        # It passed, you live... for now.
        return if $result;

        # If there's asserts in the stack, let them have a chance
        # to process before dying.
        return if $self->top_stack->in_assert;

        die "Assert failed.\n";
    };

=cut

sub assert_end {
    my $self   = shift;
    my $result = shift;

    $self->formatter->result($result) if
      $self->top_stack->at_top and defined $result;

    sanity $self->top_stack->pop;

    return;
}


=head3 set_plan

  $tb->set_plan(%plan);

Inform the builder what your test plan is, if any.

For example, Perl tests would say:

    $tb->set_plan( tests => $number_of_tests );

Extension authors are encouraged to put method modifiers on
set_plan().

=cut

sub set_plan {
    my $self = shift;
    my %plan = @_;

    $self->planned_tests($plan{tests}) if $plan{tests};

    return %plan;
}


=head3 ok

  my $result = $tb->ok( $test );
  my $result = $tb->ok( $test, $name );

The most basic assertion that all other assertions should use.

This handles things like calling C<assert_start> and C<assert_end>,
creating a test result, recording the result and incrementing the test
counter.  Everything you want an assert to do and nothing else.

$test is simple true for success, false for failure.

$name is a description of the test.

Returns a Test::Builder2::Result object representing the test.

For even more control, ass L<accept_result>.

=cut

has result_class => (
  is            => 'ro',
  isa           => 'Test::Builder2::LoadableClass',
  coerce        => 1,
  default       => 'Test::Builder2::Result',
);


sub ok {
    my $self = shift;
    my $test = shift;
    my $name = shift;

    $self->assert_start();

    my $num = $self->history->counter->get + 1;

    my $result = $self->result_class->new_result(
        test_number     => $num,
        description     => $name,
        pass            => $test,
    );

    $self->accept_result($result);

    $self->assert_end($result);

    return $result;
}


=head3 accept_result

  $tb->accept_result( $result );

Records a test $result (a Test::Builder2::Result object) to C<<
$tb->history >> AND DOES NOTHING ELSE.

You probably want to use L<ok>.

=cut

sub accept_result {
    my $self = shift;
    my $result = shift;

    $self->history->add_test_history( $result );

    return;
}


no Test::Builder2::Mouse;

1;


=head1 CONTRIBUTE

The repository for Test::Builder2 can be found at
L<http://github.com/schwern/test-more/tree/Test-Builder2>.

Issues can be discussed at
L<http://github.com/schwern/test-more/issues> or
E<lt>bugs-Test-SimpleE<0x40>rt.cpan.orgE<gt>.  We are always open to
discussion, critiques and feedback.  Doesn't matter if you're not sure
if its a "bug".  If it bugs you, let us know.


=head1 THANKS

Test::Builder2 was written with a generous grant from The Perl
Foundation using donations by viewers like you.


=head1 AUTHOR

Michael G Schwern E<lt>schwernE<0x40>pobox.comE<gt>.


=head1 COPYRIGHT

Copyright 2008-2010 by Michael G Schwern E<lt>schwernE<0x40>pobox.comE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>


=head1 SEE ALSO

L<Test::Builder2::Design> for a high level overview of how Test::Builder2 is put together.

L<Test::Builder2::Result> for the object representing the result of an assert.

L<Test::Builder2::History> for the object storing result history.

L<Test::Builder2::Formatter> for the object handling printing results.

L<Test::Buidler2::Module> for writing your own test libraries.

=cut
