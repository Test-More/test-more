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
    for my $munger_id (sort {$a <=> $b} keys %{$self->{mungers}}) {
        my $new_items;

        push @$new_items => $self->{mungers}->{$munger_id}->($tb, $_) for @$items;

        $items = $new_items;
    }

    for my $item (@$items) {
        for my $listener (values %{$self->{listeners}}) {
            $listener->($tb, $item);
        }
    }
}

1;
