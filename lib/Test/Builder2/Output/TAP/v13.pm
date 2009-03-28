package Test::Builder2::Output::TAP::v13;

use 5.006;
use strict;

use Mouse;
use Carp;


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

=head3 new

  my $output = Test::Builder2::Output::TAP::v13->new(%args);

Sets up a new output object to feed results.

All %args are optional.

    output_fh     a filehandle to send test output
                  [default STDOUT]
    failure_fh    a filehandle to send failure information
                  [default STDERR]
    error_fh      a filehandle to send errors
                  [default STDERR]

NOTE:  Might turn these into output objects later.

=cut

has output_fh =>
  is            => 'rw',
#  isa           => 'FileHandle',  # Mouse has a bug
  default       => *STDOUT;

has failure_fh =>
  is            => 'rw',
#  isa           => 'FileHandle',
  default       => *STDERR;

has error_fh =>
  is            => 'rw',
#  isa           => 'FileHandle',
  default       => *STDERR;


=head3 trap_output

  $output->trap_output;

=cut

sub trap_output {
    my $self = shift;

    my %outputs = (
        all  => '',
        out  => '',
        err  => '',
        todo => '',
    );
    $self->{_outputs} = \%outputs;

    require Test::Builder::Tee;
    tie *OUT,  "Test::Builder::Tee", \$outputs{all}, \$outputs{out};
    tie *ERR,  "Test::Builder::Tee", \$outputs{all}, \$outputs{err};
    tie *TODO, "Test::Builder::Tee", \$outputs{all}, \$outputs{todo};

    $self->output_fh(*OUT);
    $self->failure_fh(*ERR);
    $self->error_fh(*TODO);

    return;
}

sub read {
    my $self = shift;
    my $stream = @_ ? shift : 'all';

    my $out = $self->{_outputs}{$stream};

    $self->{_outputs}{$stream} = '';

    # Clear all the streams if 'all' is read.
    if( $stream eq 'all' ) {
        my @keys = keys %{$self->{_outputs}};
        $self->{_outputs}{$_} = '' for @keys;
    }

    return $out;
}


=head3 begin

  $output->begin;
  $output->begin(%plan);

Indicates that testing is going to begin.  Gives $output the
opportunity to output a plan.

A %plan can be given.  It can be one and only one of...

  tests => $number_of_tests

or

  no_plan => 1

or

  skip_all => $reason

=cut

sub begin {
    my $self = shift;
    my %args = @_;

    croak "begin() takes only one pair of arguments" if keys %args > 1;

    $self->_out("TAP version 13\n");

    if( exists $args{tests} ) {
        $self->_out("1..$args{tests}\n");
    }
    elsif( exists $args{skip_all} ) {
        $self->_out("1..0 # skip $args{skip_all}");
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


sub _out {
    my $self = shift;
    my $fh = $self->output_fh;
    print $fh @_;
}

=head3 result

  $output->result($result);

Outputs a $result.

If begin() has not yet been called it will be.

=head3 end

  $output->end;
  $output->end(%plan);

Indicates that testing is done.

The %plan arguments are the same as begin().

=cut

1;
