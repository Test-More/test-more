package Test::Builder2::Output;

use strict;
use Mouse;


=head1 NAME

Test::Builder2::Output - Base class for outputting test results

=head1 SYNOPSIS

  package Test::Builder2::Output::SomeFormat;

  use Mouse;
  extends "Test::Builder2::Output;

=head1 DESCRIPTION

Test::Builder2 delegates the actual output of test results to a
Test::Builder2::Output object.  This can then decide if it's going to
output TAP or XML or send email or whatever.

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


=head3 begin

  $output->begin;
  $output->begin(%plan);

Indicates that testing is going to begin.  Gives $output the
opportunity to output a plan, do setup or output opening tags and
headers.

A %plan can be given, but there are currently no common attributes.

=cut

sub begin {
    my $self = shift;

    $self->INNER_begin(@_);

    return;
}


=head3 result

  $output->result($result);

Outputs a $result.

If begin() has not yet been called it will be.

=cut

sub result {
    my $self = shift;

    $self->INNER_result(@_);

    return;
}


=head3 end

  $output->end;
  $output->end(%plan);

Indicates that testing is done.  Gives $output the opportunity to
clean up, output closing tags, save the results or whatever.

No further results should be output after end().

=cut

sub end {
    my $self = shift;

    $self->INNER_end(@_);

    return;
}


=head3 out

  $output->out(@text);

Outputs @text to C<<$output->output_fh>>.

@text is treated like C<print> so it is simply concatenated.

None of the global variables which effect print ($\, $" and so on)
will effect C<out()>.

=head3 fail

Same as C<out()> but using C<<$output->failure_fh>>.

=head3 error

Same as C<out()> but using C<<$output->error_fh>>.

=cut

sub _print {
    my $self = shift;
    my $fh   = shift;

    # Prevent setting these in the tests from effecting our output
    local( $\, $", $, ) = ( undef, ' ', '' );

    return print $fh @_;
}

sub out {
    my $self = shift;

    return $self->_print($self->output_fh, @_);
}

sub fail {
    my $self = shift;

    return $self->_print($self->failure_fh, @_);
}

sub error {
    my $self = shift;

    return $self->_print($self->error_fh, @_);
}


=head3 trap_output

  $output->trap_output;

Causes $output to store all output instead of sending it to its
filehandles.

A convenience method for testing.

See C<read> for how to get at the stored output.

=cut

sub trap_output {
    my $self = shift;

    my %outputs = (
        all  => '',
        out  => '',
        err  => '',
        fail => '',
    );
    $self->{_outputs} = \%outputs;

    require Test::Builder::Tee;
    tie *OUT,  "Test::Builder::Tee", \$outputs{all}, \$outputs{out};
    tie *ERR,  "Test::Builder::Tee", \$outputs{all}, \$outputs{err};
    tie *FAIL, "Test::Builder::Tee", \$outputs{all}, \$outputs{todo};

    $self->output_fh(*OUT);
    $self->failure_fh(*FAIL);
    $self->error_fh(*ERR);

    return;
}


=head3 read

    my $all_output = $tb->read;
    my $output     = $tb->read($stream);

Only useful after trap_output() has been called.

Returns all the output (including failure and todo output) collected
so far.  It is destructive, each call to read clears the output
buffer.

If $stream is given it will return just the output from that stream.
$stream's are...

    out        output_fh()
    fai        failure_fh()
    err        error_fh()
    all        all outputs

Defaults to 'all'.

=cut

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


=head2 Virtual Methods

These methods must be defined by the subclasser.

Do not override begin, result and end.  Override these instead.

=head3 INNER_begin

=head3 INNER_result

=head3 INNER_end

These implement the guts of begin, result and end.

=cut

1;
