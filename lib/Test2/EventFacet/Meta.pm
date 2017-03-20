package Test2::EventFacet::Meta;
use strict;
use warnings;

our $VERSION = '1.302079';

BEGIN { require Test2::EventFacet; our @ISA = qw(Test2::EventFacet) }
use vars qw/$AUTOLOAD/;

# replace set_details
{
    no warnings 'redefine';
    sub set_details { $_[0]->{'set_details'} }
}

sub can {
    my $self = shift;
    my ($name) = @_;

    my $existing = $self->SUPER::can($name);
    return $existing if $existing;

    my $sub = sub { $_[0]->{$name} };
    {
        no strict 'refs';
        *$name = $sub;
    }

    return $sub;
}

sub AUTOLOAD {
    my $name = $AUTOLOAD;
    $name =~ s/^.*:://g;
    my $sub = $_[0]->can($name);
    goto &$sub;
}

1;
