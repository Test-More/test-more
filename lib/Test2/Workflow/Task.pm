package Test2::Workflow::Task;
use strict;
use warnings;

use Test2::API();
use Test2::Event::Exception();

use Carp qw/croak/;

use base 'Test2::Workflow::BlockBase';
use Test2::Util::HashBase qw/name flat async iso todo skip scaffold/;

for my $attr (FLAT, ASYNC, TODO, SKIP, SCAFFOLD) {
    my $old = __PACKAGE__->can("set_$attr");
    my $new = sub {
        my $self = shift;
        my $out = $self->$old(@_);
        $self->verify_scaffold;
        return $out;
    };

    no strict 'refs';
    no warnings 'redefine';
    *{"set_$attr"} = $new;
}

sub init {
    my $self = shift;

    {
        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $self->SUPER::init();
    }

    croak "the 'name' attribute is required"
        unless $self->name;

    $self->verify_scaffold;
}

sub verify_scaffold {
    my $self = shift;

    return unless $self->{+SCAFFOLD};

    croak "The 'flat' attribute must be true for scaffolding"
        if defined($self->{+FLAT}) && !$self->{+FLAT};

    $self->{+FLAT} = 1;

    for my $attr (ISO, ASYNC, TODO, SKIP) {
        croak "The '$attr' attribute cannot be used on scaffolding"
            if $self->{$attr};
    }
}

sub exception {
    my $self = shift;
    my ($err) = @_;

    my $trace = $self->trace;

    Test2::API::test2_stack->top->send(
        Test2::Event::Exception->new(
            trace => $trace,
            error => $err,
        )
    );
}

1;
