package Test::Builder2::Formatter::Null;

use Test::Builder2::Mouse;

extends 'Test::Builder2::Formatter';


=head1 NAME

Test::Builder2::Formatter::Null - A formatter that does nothing


=head1 SYNOPSIS

    use Test::Builder::Formatter::Null;
    my $null = Test::Builder2::Formatter::Null->new;

    # Make your tests output nothing
    $tb->formatter($null);


=head1 DESCRIPTION

This formatter will do nothing.  Its useful if you want your tests to
produce no output.

=cut

sub accept_event  {}
sub accept_result {}

1;
