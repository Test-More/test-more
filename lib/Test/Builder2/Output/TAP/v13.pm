package Test::Builder2::Output::TAP::v13;

use 5.006;
use strict;

use Mouse;
use Carp;

extends 'Test::Builder2::Output';


=head1 NAME

Test::Builder2::Output::TAP::v13 - Output as TAP version 13

=head1 SYNOPSIS

  use Test::Builder2::Output::TAP::v13;

  my $output = Test:::Builder2::Output::TAP::v13->new;
  $output->begin();
  $output->result($result);
  $output->end($plan);


=head1 DESCRIPTION

Output Test::Builder2::Result's as TAP version 13.

=head1 METHODS

As Test::Builder2::Object with the following changes and additions.

=head3 begin

The %plan can be one and only one of...

  tests => $number_of_tests

  no_plan => 1

  skip_all => $reason

=cut

sub begin {
    my $self = shift;
    my %args = @_;

    croak "begin() takes only one pair of arguments" if keys %args > 1;

    $self->out("TAP version 13\n");

    if( exists $args{tests} ) {
        $self->out("1..$args{tests}\n");
    }
    elsif( exists $args{skip_all} ) {
        $self->out("1..0 # skip $args{skip_all}");
    }
    elsif( exists $args{no_plan} ) {
        # ...do nothing...
    }
    elsif( keys %args == 1 ) {
        croak "Unknown argument @{[ keys %args ]} to begin()";
    }
    else {
        # ...do nothing...
    }

    return;
}


=head3 end

Similar to C<begin()>, it takes either no or one and only one pair of arguments.

  tests => $number_of_tests

=cut

sub end {
    my $self = shift;

    my %args = @_;

    croak "end() takes only one pair of arguments" if keys %args > 1;

    if( exists $args{tests} ) {
        $self->out("1..$args{tests}\n");
    }
    elsif( keys %args == 1 ) {
        croak "Unknown argument @{[ keys %args ]} to begin()";
    }
    else {
        # ...do nothing...
    }

    return;    
}

1;
