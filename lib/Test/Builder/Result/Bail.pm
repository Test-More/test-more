package Test::Builder::Result::Bail;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Test::Builder::Util qw/accessors/;
accessors qw/reason/;

sub to_tap {
    my $self = shift;
    return "Bail out!  " . $self->reason . "\n";
}

1;
