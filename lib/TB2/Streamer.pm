package TB2::Streamer;

use TB2::Mouse ();
use TB2::Mouse::Role;

our $VERSION = '1.005000_004';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

requires 'write';

no TB2::Mouse::Role;
1;


=head1 NAME

TB2::Streamer - Role to output formatted test results

=head1 SYNOPSIS

    package My::Streamer;

    sub write {
        my($self, $destination, @text) = @_;

        if( $destination eq 'output' ) {
            print STDOUT @text;
        }
        elsif( $destination eq 'error' ) {
            print STDERR @text;
        }
        else {
            croak "I don't know how to stream to $destination";
        }
    }

=head1 DESCRIPTION

A streamer object is used to output formatted test results (or really
any text).  You can use it to just spit stuff to STDOUT and STDERR,
trap stuff for debugging, or... uhh... something else.

TB2::Streamer is just a role, you must write your own
streamer or use one of the existing ones (see L<SEE ALSO>).


=head2 Required Methods

You are only required to write a single method:

=head3 write

    $self->write( $destination => @output );

This method accepts @output and streams it to the given $destination.

The $destination has meaning specific to the Streamer.

It must throw an exception if it fails.


=head1 SEE ALSO

L<TB2::Streamer::Print> Print to a configurable output filehandle

L<TB2::Streamer::Debug> Captures all output, useful for debugging.

=cut
