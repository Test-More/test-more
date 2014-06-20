package Test::Builder::Result::Note;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Test::Builder::Util qw/accessors/;
accessors qw/message/;

sub to_tap {
    my $self = shift;

    my $msg = $self->message;
    $msg =~ s/^/# /;

    return $msg;
}

1;
