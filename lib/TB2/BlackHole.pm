package TB2::BlackHole;

use TB2::Mouse;

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


use overload
  "bool"        => sub { 0 };


sub AUTOLOAD {
    # It's black holes all the way down.
    return __PACKAGE__->new;
}


=head1 NAME

TB2::BlackHole - Goes Nowhere Does Nothing

=head1 SYNOPSIS

    use TB2::BlackHole;
    my $blackhole = TB2::BlackHole->new;

    $blackhole->whatever;
    $blackhole->destroy_the_universe( pretty => "please" );

=head1 DESCRIPTION

This is an object that accepts any method with any argument and
returns another BlackHole object.  This allows chained black holes
like...

    $thing->what->huh->oh;

BlackHole objects are always boolean false so code like this DTRT.

    if( $thing->what ) { ... }

You'd use this if you have an optional object, but don't want everyone
to check if they have it.  For example, a formatter.  This may turn
out to be a really bad idea.

=cut

no TB2::Mouse;

1;
