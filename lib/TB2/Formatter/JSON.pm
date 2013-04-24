package TB2::Formatter::JSON;

use TB2::Mouse;
extends "TB2::Formatter";


=head1 NAME

TB2::Formatter::JSON - Output event objects as a JSON list

=head1 DESCRIPTION

This formatter outputs all events as a list of JSON items.  The
items are events dumped using C<< TB2::Event->as_hash >>.  These
events can be restored as L<TB2::Event::Generic> objects.

    use TB2::Event::Generic;
    use JSON;

    my @$events_as_hash = decode_json( $events_as_json );
    my @events = map { TB2::Event::Generic->new( $_ ) } @$events_as_hash;

This is useful for debugging or as an interprocess communication
mechanism.  The reader of the JSON stream will have all the same
information as an event handler does.

Set the TB2_FORMATTER_CLASS environment variable to
TB2::Formatter::JSON.

=head1 NOTES

Requires JSON::PP which is not a requirement of Test::More.  This
module will likely be split out of the Test-Simple distribution.  If
you use it, be sure to declare it.

=cut

{
    my $json;
    sub json {
        require JSON::PP;
        $json ||= JSON::PP->new
                          ->utf8
                          ->pretty
                          ->allow_unknown
                          ->allow_blessed;

        return $json;
    }
}

sub handle_test_start {
    my $self = shift;
    my($event, $ec) = @_;

    $self->write(out => "[\n");
    $self->_event2json($event);

    return;
}

sub handle_test_end {
    my $self = shift;
    my($event, $ec) = @_;

    $self->write(out => ",\n");
    $self->_event2json($event);
    $self->write(out => "]\n");

    return;
}

sub handle_event {
    my $self = shift;
    my($event, $ec) = @_;

    $self->write(out => ",\n");
    $self->_event2json($event);

    return;
}

sub _event2json {
    my $self = shift;
    my($event) = @_;

    $self->write(out => $self->json->encode($event->as_hash) );

    return;
}

1;
