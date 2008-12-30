package Test::Builder2;

use 5.006;
use Mouse;

use Test::Builder2::History;
use Test::Builder2::Result;


=head1 NAME

Test::Builder2 - 2nd Generation test library builder

=head1 SYNOPSIS

=head1 DESCRIPTION

Just a stub at this point to get things off the ground.

=head2 METHODS

=head3 history

=cut

has history =>
  is            => 'rw',
  isa           => 'Test::Builder2::History',
  default       => sub { Test::Builder2::History->new };

=head3 planned_tests

=cut

has planned_tests =>
  is            => 'rw',
  isa           => 'Int',
  default       => 0;

=head3 test_start

=cut

sub test_start {
}

=head3 test_end

=cut

sub test_end {
}

=head3 plan

=cut

sub plan {
    my $self = shift;
    my %args = @_;

    $self->planned_tests( $args{tests} );

    print "1..$args{tests}\n";
}

=head3 ok

=cut

sub ok {
    my $self = shift;
    my $test = shift;

    my $num = $self->history->next_test_number;
    print $test ? "ok $num\n" : "not ok $num\n";

    $self->history->add_test_history( Test::Builder2::Result::Pass->new(
        test_number => $num
    ) );

    return $test ? 1 : 0;
}

1;
