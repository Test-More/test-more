package Test::Builder::Result::Ok;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Data::Dumper;

use Carp qw/confess/;
use Test::Builder::Util qw/accessors/;

accessors qw/bool real_bool name todo skip/;

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $out = "";
    $out .= "not " unless $self->real_bool;
    $out .= "ok";
    $out .= " $num" if defined $num;

    if (defined $self->name) {
        my $name = $self->name;
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        $out .= " - " . $name;
    }

    if (defined $self->skip && defined $self->todo) {
        my $why = $self->skip;

        confess "2 different reasons to skip/todo: " . Dumper($self)
            unless $why eq $self->todo;

        $out .= " # TODO & SKIP $why";
    }
    elsif (defined $self->skip) {
        $out .= " # skip";
        $out .= " " . $self->skip if length $self->skip;
    }
    elsif($self->in_todo) {
        $out .= " # TODO " . $self->todo if $self->in_todo;
    }

    $out =~ s/\n/\n# /g;

    $out .= "\n";

    return $out;
}

1;
