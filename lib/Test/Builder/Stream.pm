package Test::Builder::Stream;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/reftype blessed/;

sub new {
    my $class = shift;
    return bless { listeners => {}, mungers => {} }, $class;
}

my $listen_id = 1;
sub listen {
    my $self = shift;
    my ($listener) = @_;

    confess("Listeners must be code refs")
        unless $listener && reftype $listener and reftype $listener eq 'CODE';

    my $id = $listen_id++;
    my $listeners = $self->{listeners};
    $listeners->{$id} = $listener;
    return sub { delete $listeners->{$id} };
}

my $munge_id = 1;
sub munge {
    my $self = shift;
    my ($munger) = @_;

    confess("Mungers must be code refs")
        unless $munger && reftype $munger and reftype $munger eq 'CODE';

    my $id = $munge_id++;
    my $mungers = $self->{mungers};
    $mungers->{$id} = $munger;
    return sub { delete $mungers->{$id} };
}

sub push {
    my $self = shift;
    my ($tb, $item) = @_;

    confess("Did not get a Test::Builder! ($tb)")
        unless $tb && blessed($tb) && $tb->isa('Test::Builder');

    my $items = [$item];
    for my $munger (values %{$self->{mungers}}) {
        my $new_items;

        push @$new_items => $munger->($tb, $_) for @$items;

        $items = $new_items;
    }

    for my $item (@$items) {
        for my $listener (values %{$self->{listeners}}) {
            $listener->($tb, $item);
        }
    }
}

sub TAP {
    my ($tb, $item) = @_;
    if ($item->isa('Test::Builder::Result::Ok')) {
        TAP_Ok($tb, $item);
    }
    elsif($item->isa('Test::Builder::Result::Diag')) {
        TAP_Diag($tb, $item);
    }
    elsif($item->isa('Test::Builder::Result::Note')) {
        TAP_Note($tb, $item);
    }
    elsif($item->isa('Test::Builder::Result::Plan')) {
        TAP_Plan($tb, $item);
    }
    elsif($item->isa('Test::Builder::Result::Bail')) {
        TAP_Bail($tb, $item);
    }
    elsif($item->isa('Test::Builder::Result::Nest')) {
        TAP_Nest($tb, $item);
    }
    # Tap does not handle any others, ignore!
}

sub TAP_Ok {
    my ($tb, $ok) = @_;

    my $out = "";
    $out .= "not " unless $ok->real_bool;
    $out .= "ok";
    $out .= " " . $ok->number if $tb->use_numbers;

    if (defined $ok->name) {
        my $name = $ok->name;
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        $out .= " - " . $name;
    }

    $out .= " # TODO " . $ok->todo if $tb->in_todo;
    $out .= "\n";

    $tb->_print($out);
}

sub TAP_Diag {
}

sub TAP_Note {
}

sub TAP_Plan {
}

sub TAP_Bail {
}

sub TAP_Nest {
}

1;
