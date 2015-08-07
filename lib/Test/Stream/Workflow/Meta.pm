package Test::Stream::Workflow::Meta;
use strict;
use warnings;

use Carp qw/confess/;

use Test::Stream::Workflow::Unit;

use Test::Stream::HashBase(
    accessors => [qw/unit runner runner_args autorun/],
);

my %METAS;

sub init {
    my $self = shift;

    confess "unit is a required attribute"
        unless $self->{+UNIT};
}

sub build {
    my $class = shift;
    my ($pkg, $file, $start_line, $end_line) = @_;

    return $METAS{$pkg} if $METAS{$pkg};

    my $unit = Test::Stream::Workflow::Unit->new(
        name       => $pkg,
        package    => $pkg,
        file       => $file,
        start_line => $start_line,
        end_line   => $end_line,
        type       => 'group'
    );

    my $meta = $class->new(
        UNIT()    => $unit,
        AUTORUN() => 1,
    );

    $METAS{$pkg} = $meta;

    my $hub = Test::Stream::Sync->stack->top;
    $hub->follow_up(
        sub {
            return unless $METAS{$pkg};
            return unless $METAS{$pkg}->autorun;
            $METAS{$pkg}->run;
        }
    );
}

sub get {
    my $class = shift;
    my ($pkg) = @_;
    return $METAS{$pkg};
}

sub run {
    my $self = shift;
    my $runner = $self->runner;
    unless ($runner) {
        require Test::Stream::Workflow::Runner;
        $runner = Test::Stream::Workflow::Runner->new;
    }

    $self->unit->do_post;

    $runner->run(
        unit => $self->unit,
        args => $self->runner_args || [],
        no_final => 1
    );
}

1;
