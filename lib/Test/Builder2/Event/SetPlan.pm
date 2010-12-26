package Test::Builder2::Event::SetPlan;

use Test::Builder2::Types;
use Test::Builder2::Mouse;
with 'Test::Builder2::Event';


=head1 NAME

Test::Builder2::Event::SetPlan - Set the plan for the current stream

=head1 DESCRIPTION

This is an Event indicating that the test plan for the current stream
has been set.

It B<must> come between a C<stream start> and an C<stream end> Event.

=head1 METHODS

=head2 Attributes

=head3 asserts_expected

The total number of asserts expected to be in this stream.

Must be a positive integer or 0.

Defaults to 0.

=cut

has asserts_expected =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_Int',
  default       => 0,
;


=head3 no_plan

If true, there is explicitly no plan for this stream.  Any positive
number of asserts is fine.

Defaults to false.

=cut

has no_plan     =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;


=head3 skip

If true, it indicates that the rest of the asserts in the stream will
not be executed.  Usually because they would not make sense in the
current environment (Unix tests on Windows, for example).

No results should follow in this stream.

Defaults to false.

=cut

has skip        =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

=head3 skip_reason

The reason the stream has been skipped.

Defaults to empty string.

=cut

has skip_reason =>
  is            => 'rw',
  isa           => 'Str',
  default       => ''
;

=head3 plan

A hash ref containing any further information about the plan.

Defaults to an empty hash ref.

=cut

has plan =>
  is            => 'rw',
  isa           => 'HashRef',
  lazy          => 1,
  default       => sub { {} }
;

=head3 event_type

The event type is C<set plan>.

=cut

sub event_type { "set plan" }

my @data_methods = qw(plan asserts_expected no_plan skip skip_reason event_type);
sub as_hash {
    my $self = shift;

    my %data;
    for my $method (@data_methods) {
        $data{$method} = $self->$method();
    }

    return \%data;
}


=head1 SEE ALSO

L<Test::Builder2::Event>

1;
