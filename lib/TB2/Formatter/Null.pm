package TB2::Formatter::Null;

use TB2::Mouse;
extends 'TB2::Formatter';

our $VERSION = '1.005000_003';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Formatter::Null - A formatter that does nothing


=head1 SYNOPSIS

    use Test::Builder::Formatter::Null;
    my $null = TB2::Formatter::Null->new;

    # Make your tests output nothing
    $tb->formatter($null);


=head1 DESCRIPTION

This formatter will do nothing.  Its useful if you want your tests to
produce no output.

=cut

1;
