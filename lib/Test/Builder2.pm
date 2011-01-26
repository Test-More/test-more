package Test::Builder2;

use 5.008001;
use Test::Builder2::Mouse;
use Test::Builder2::Types;
use Test::Builder2::Events;

with 'Test::Builder2::Singleton',
     'Test::Builder2::CanTry',
     'Test::Builder2::CanLoad';

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


=head1 METHODS

=head3 event_coordinator

    my $event_coordinator = $builder->event_coordinator;
    $builder->event_coordinator($event_coordinator);

Get/set the L<Test::Builder2::EventCoordinator> associated with this C<$builder>.

By default it creates a new EventCoordinator detached from other builders.

The singleton contains the EventCoordinator singleton.

=cut

has event_coordinator =>
  is            => 'rw',
  isa           => 'Test::Builder2::EventCoordinator',
  default       => sub {
      $_[0]->load('Test::Builder2::EventCoordinator');
      return Test::Builder2::EventCoordinator->create;
  }
;

sub make_singleton {
    my $class = shift;

    $class->load('Test::Builder2::EventCoordinator');
    return $class->create(
        event_coordinator => Test::Builder2::EventCoordinator->singleton
    );
}


=head3 history

    my $history = $builder->history;

A convenience method to access the first History object associated
with the C<event_coordinator>.

Note that there can be more than one.

=cut

sub history {
    return $_[0]->event_coordinator->history;
}


=head3 formatter

    my $formatter = $builder->formatter;

A convenience method to access the first Formatter associated
with the C<event_coordinator>.

Note that there can be more than one.

=cut

sub formatter {
    return $_[0]->event_coordinator->formatters->[0];
}


=head3 top_stack

  my $top_stack = $tb->top_stack;

Stores the current stack of asserts being run as a
Test::Builder2::AssertStack.

=cut

has top_stack =>
  is            => 'ro',
  isa           => 'Test::Builder2::AssertStack',
  default       => sub {
      $_[0]->load('Test::Builder2::AssertStack');
      Test::Builder2::AssertStack->new;
  };


=head3 stream_start

  $tb->stream_start;

Inform the builder that testing is about to begin.

This should be called before any set of asserts is run.

It should eventually be followed by a call to L<stream_end>.

You can indicate nested sets of asserts by calling C<stream_start>
before C<stream_end>.

=cut

sub stream_start {
    my $self = shift;

    $self->event_coordinator->post_event(
        Test::Builder2::Event::StreamStart->new
    );

    return;
}

=head3 stream_end

  $tb->stream_end;

Inform the Builder that a set of asserts is complete.

=cut

sub stream_end {
    my $self = shift;

    $self->event_coordinator->post_event(
        Test::Builder2::Event::StreamEnd->new
    );

    return;
}


=head3 set_plan

  $tb->set_plan(%plan);

Inform the builder what your test plan is, if any.

For example, Perl tests would say:

    $tb->set_plan( tests => $number_of_tests );

=cut

sub set_plan {
    my $self = shift;
    my %input = @_;

    my %plan;
    $plan{asserts_expected} = delete $input{tests} if exists $input{tests};

    my @keys = qw(no_plan skip skip_reason);
    for my $key (@keys) {
        $plan{$key} = delete $input{$key} if exists $input{$key};
    }

    # Whatever's left
    $plan{plan} = \%input if keys %input;

    my $plan = Test::Builder2::Event::SetPlan->new(
        %plan
    );

    $self->event_coordinator->post_event($plan);

    return;
}


=head3 assert_start

  $tb->assert_start;

Called just before a user written test function begins, an assertion.

Most users should call C<ok> instead.

By default it records the caller at this point in C<< $self->top_stack >>
for the purposes of reporting test file and line numbers properly.

This will be called when *any* assertion begins.  If you want to
know when the assertion is called from the user's point of view, check
C<< $self->top_stack >>.  It will be empty before and have a single
assert after.

=cut

sub assert_start {
    my $self = shift;

    $self->load('Test::Builder2::AssertRecord');
    my $record = Test::Builder2::AssertRecord->new_from_caller(1);
    sanity $record;

    $self->top_stack->push($record);

    return;
}

=head3 assert_end

  $tb->assert_end($result);

Like C<assert_start> but for just after a user written assert function
finishes.

Most users should call C<ok> instead.

By default it pops C<< $self->top_stack >> and if this is the last
assert in the stack it formats the result.

This will be called when *any* assertion ends.  If you want to know
when the assertion is complete from the user's point of view, check
C<< $self->top_stack >>.  It will have a single element before and be
empty after.

=cut

sub assert_end {
    my $self   = shift;
    my $result = shift;

    # Trap an error from a watcher...
    my($ret, $error) = $self->try( sub {
        $self->event_coordinator->post_result($result) if
          $self->top_stack->at_top and defined $result;
        1;
    });

    # ...because we have to pop the stack no matter what...
    sanity $self->top_stack->pop;

    # ...then rethrow it.
    die $error if $error;

    return;
}


=head3 ok

  my $result = $tb->ok( $test );
  my $result = $tb->ok( $test, $name );

The most basic assertion that all other assertions should use.

This handles things like calling C<assert_start>, C<assert_end>,
creating a test result and recording the result.  It will start a
stream if one is not already started.  Everything you want an assert
to do and nothing else.

$test is simple true for success, false for failure.

$name is a description of the test.

Returns a Test::Builder2::Result object representing the test.

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

    $self->stream_start unless $self->history->stream_depth;

    $self->assert_start();

    my $result = $self->result_class->new_result(
        description     => $name,
        pass            => $test,
    );

    my $top = $self->top_stack->top;
    $result->file($top->filename);
    $result->line($top->line);

    $self->assert_end($result);

    return $result;
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

See L<http://dev.perl.org/licenses/artistic.html>


=head1 SEE ALSO

L<Test::Builder2::Design> for a high level overview of how Test::Builder2 is put together.

L<Test::Builder2::Result> for the object representing the result of an assert.

L<Test::Builder2::History> for the object storing result history.

L<Test::Builder2::Formatter> for the object handling printing results.

L<Test::Builder2::EventCoordinator> for the object coordinating between builders.

L<Test::Builder2::Module> for writing your own test libraries.

=cut
