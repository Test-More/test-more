package TB2::Formatter::Multi;

use TB2::Mouse;
extends 'TB2::Formatter';

our $VERSION = '1.005000_003';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Formatter::Multi - Use multiple formatters at once


=head1 SYNOPSIS

    use TB2::Formatter::Multi;

    my $multi = TB2::Formatter::Multi->new;
    $multi->add_formatters($this_formatter, $that_formatter);

    # Equivalent to
    #   $this_formatter->handle_result($result, $ec);
    #   $that_formatter->handle_result($result, $ec);
    $multi->handle_result($result, $ec);


=head1 DESCRIPTION

This is a formatter which allows you to use multiple formatters at the
same time.  It does no work on its own but passes it on to its list of
formatters.  You might want this to store the results as TAP while
also writing them out as HTML.

A Multi instance does not have a streamer of its own.


=head1 METHODS

This has all the normal methods of a Formatter plus...

=head3 formatters

Gets/sets the list of Formatter objects to multiplex to.

=head3 add_formaters

    $multi->add_formatters(@formatters);

A convenience method to add @formatters to C<< $multi->formatters >>.

=cut

has formatters =>
  is            => 'rw',
  isa           => 'ArrayRef[TB2::Formatter]',
  default       => sub { [] }
;

sub add_formatters {
    my $self = shift;
    push @{$self->formatters}, @_;
    return;
}

sub accept_event {
    my $self = shift;

    for my $formatter (@{ $self->formatters }) {
        $formatter->accept_event(@_);
    }
}


1;
