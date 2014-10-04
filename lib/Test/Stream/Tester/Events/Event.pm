package Test::Stream::Tester::Events::Event;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my @orig = @_;

    while (@_) {
        my $field = shift;
        my $val   = shift;

        if (exists $self->{$field}) {
            use Data::Dumper;
            print Dumper(@orig);
            confess "'$field' specified more than once!";
        }

        $self->{$field} = $val;
    }

    return $self;
}

sub get {
    my $self = shift;
    my ($field) = @_;
    return $self->{$field};
}

sub debug {
    my $self = shift;

    my $type = $self->get('type');
    my $file = $self->get('file');
    my $line = $self->get('line');

    return "'$type' from $file line $line.";
}

1;
