package Test::Stream::Tester::Checks::Event;
use strict;
use warnings;

use Test::Stream::Util qw/is_regex/;
use Test::Stream::Carp qw/confess croak/;

use Scalar::Util qw/blessed reftype/;

sub new {
    my $class = shift;
    my $fields = {@_};
    my $self = bless {fields => $fields}, $class;

    $self->{$_} = delete $fields->{$_}
        for qw/debug_line debug_file debug_package/;

    map { $self->validate_check($_) } values %$fields;

    my $type = $self->get('type') || confess "No type specified!";

    my $etypes = Test::Stream::Context->events;
    confess "'$type' is not a valid event type"
        unless $etypes->{$type};

    return $self;
}

sub debug_line    { shift->{debug_line}    }
sub debug_file    { shift->{debug_file}    }
sub debug_package { shift->{debug_package} }

sub debug {
    my $self = shift;

    my $type = $self->get('type');
    my $file = $self->debug_file;
    my $line = $self->debug_line;

    return "'$type' from $file line $line.";
}

sub keys { sort keys %{shift->{fields}} }

sub exists {
    my $self = shift;
    my ($field) = @_;
    return exists $self->{fields}->{$field};
}

sub get {
    my $self = shift;
    my ($field) = @_;
    return $self->{fields}->{$field};
}

sub validate_check {
    my $self = shift;
    my ($val) = @_;

    return unless defined $val;
    return unless ref $val;
    return if is_regex($val);

    if (blessed($val)) {
        return if $val->isa('Test::Stream::Tester::Checks');
        return if $val->isa('Test::Stream::Tester::Events');
        return if $val->isa('Test::Stream::Tester::Checks::Event');
        return if $val->isa('Test::Stream::Tester::Events::Event');
    }

    croak "'$val' is not a valid field check"
        unless reftype($val) eq 'ARRAY';

    croak "Arrayrefs given as field checks may only contain regexes"
        if grep { !is_regex($_) } @$val;

    return;
}

1;
