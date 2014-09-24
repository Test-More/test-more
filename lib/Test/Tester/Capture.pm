package Test::Tester::Capture;
use strict;
use warnings;

use base 'Test::Builder';
use Test::Stream qw/STATE_LEGACY/;

sub new {
    my $class = shift;
    my $self = $class->SUPER::create(@_);
    $self->{stream}->set_use_tap(0);
    $self->{stream}->set_use_legacy(1);
    return $self;
}

sub details {
    my $self = shift;

    my $prem;
    my @out;
    for my $e (@{$self->{stream}->state->[-1]->[STATE_LEGACY]}) {
        if ($e->isa('Test::Stream::Event::Ok')) {
            push @out => $e->to_legacy;
            $out[-1]->{diag} ||= "";
            $out[-1]->{depth} = $e->level;
            for my $d (@{$e->diag || []}) {
                next if $d->message =~ m{Failed test .*\n\s*at .* line \d+\.};
                chomp(my $msg = $d->message);
                $msg .= "\n";
                $out[-1]->{diag} .= $msg;
            }
        }
        elsif ($e->isa('Test::Stream::Event::Diag')) {
            chomp(my $msg = $e->message);
            $msg .= "\n";
            if (!@out) {
                $prem .= $msg;
                next;
            }
            next if $msg =~ m{Failed test .*\n\s*at .* line \d+\.};
            $out[-1]->{diag} .= $msg;
        }
    }

    return ($prem, @out) if $prem;
    return @out;
}

1;
