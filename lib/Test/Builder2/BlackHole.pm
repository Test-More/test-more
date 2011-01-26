package Test::Builder2::BlackHole;

use Test::Builder2::Mouse;

use overload
  "bool"        => sub { 0 };


sub AUTOLOAD {
    # It's black holes all the way down.
    return __PACKAGE__->new;
}


=head1 NAME

Test::Builder2::BlackHole - Goes Nowhere Does Nothing

=head1 SYNOPSIS

    use Test::Builder2::BlackHole;
    my $blackhole = Test::Builder2::BlackHole->new;

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

no Test::Builder2::Mouse;

1;
