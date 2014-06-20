package Test::Builder::Result::Diag;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Test::Builder::Util qw/accessors/;
accessors qw/message/;

sub to_tap {
    my $self = shift;

    my $msg = $self->message;
    unless($msg =~ m/^\n/s) {
        if($msg =~ s/^/# /s) {
            $msg =~ s/# $//;
        }
    }

    return $msg;
}


1;
