package Test::Builder::Result::Note;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Test::Builder::Util qw/accessors/;
accessors qw/message/;

sub to_tap {
    my $self = shift;

    chomp(my $msg = $self->message);
    $msg = "# $msg" unless $msg =~ m/^\n/;
    $msg =~ s/\n/\n# /g;
    return "$msg\n";
}

1;
