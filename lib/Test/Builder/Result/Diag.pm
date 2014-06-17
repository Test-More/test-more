package Test::Builder::Result::Diag;
use strict;
use warnings;

use parent 'Test::Builder::Result';

Test::Builder::Result::_accessors(qw/message/);

sub to_tap {
    my $self = shift;

    my $msg = $self->message;
    $msg =~ s/^/# / unless $msg =~ m/^\n/s;

    return $msg;
}


1;
