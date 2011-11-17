package TB2::Formatter::SimpleHTML;

use TB2::Mouse;
extends "TB2::Formatter";


=head1 NAME

TB2::Formatter::SimpleHTML - A very simple HTML formatter

=head1 SYNOPSIS

    use Test::Builder2;
    use TB2::Formatter::SimpleHTML;

    my $tb2 = Test::Builder2->default;
    my $ec = $tb2->test_state;

    $ec->clear_formatters;      # remove the TAP formatter
    $ec->add_formatters(        # add the SimpleHTML formatter
        TB2::Formatter::SimpleHTML->new
    );

    $tb2->test_start;
    $tb2->ok(1, "a name");
    $tb2->ok(0, "another name");
    $tb2->ok(1);
    $tb2->test_end;

=head1 DESCRIPTION

This is a very, very simple HTML formatter to demonstrate how its done.

=cut

# Start of testing
sub handle_test_start {
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
sub handle_test_end {
    my $self = shift;

    $self->write(out => <<"HTML");
</table>
</body>
</html>
HTML

    return;
}


# A test result
sub handle_result {
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
