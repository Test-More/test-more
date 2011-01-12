package TB2::Formatter::SimpleHTML;

use Test::Builder2::Mouse;
extends "Test::Builder2::Formatter";


=head1 NAME

TB2::Formatter::SimpleHTML - A very simple HTML formatter

=head1 SYNOPSIS

    use Test::Builder2;
    use TB2::Formatter::SimpleHTML;

    my $tb2 = Test::Builder2->singleton;
    my $ec = $tb2->event_coordinator;

    $ec->clear_formatters;      # remove the TAP formatter
    $ec->add_formatters(        # add the SimpleHTML formatter
        TB2::Formatter::SimpleHTML->create
    );

    $tb2->stream_start;
    $tb2->ok(1, "a name");
    $tb2->ok(0, "another name");
    $tb2->ok(1);
    $tb2->stream_end;

=head1 DESCRIPTION

This is a very, very simple HTML formatter to demonstrate how its done.

=cut

my %event_dispatch = (
    "stream start"      => "accept_stream_start",
    "stream end"        => "accept_stream_end",
);

sub INNER_accept_event {
    my $self  = shift;
    my $event = shift;
    my $ec    = shift;

    my $type = $event->event_type;
    my $method = $event_dispatch{$type};
    return unless $method;

    $self->$method($event, $ec);

    return;
}


# Start of testing
sub accept_stream_start {
    my $self = shift;

    $self->write(out => <<"HTML");
<html>
<head>
  <title>TB2::Formatter::SimpleHTML demo</title>
</head>
<body>
<table>
    <tr><th>Result</th><th>Name</th></tr>
HTML

    return;
}


# End of testing
sub accept_stream_end {
    my $self = shift;

    $self->write(out => <<"HTML");
</table>
</body>
</html>
HTML

    return;
}


# A test result
sub INNER_accept_result {
    my $self = shift;
    my $result = shift;

    my $name = $result->name || '';
    my $ok   = $result ? "pass" : "<b>fail</b>";
    $self->write(out => <<"HTML");
    <tr><td>$ok</td><td>$name</td></tr>
HTML

    return;
}

1;
