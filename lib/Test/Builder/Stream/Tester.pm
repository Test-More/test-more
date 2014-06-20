package Test::Builder::Stream::Tester;
use strict;
use warnings;

use Test::Builder::Stream;

use Exporter qw/import/;
use Scalar::Util qw/blessed/;

use parent 'Test::Builder::Formatter';

our @EXPORT = qw/intercept/;

sub intercept(&;$) {
    my ($code, $tb) = @_;

    my @results;

    local $@;
    my $ok = eval {
        Test::Builder::Stream->intercept(sub {
            my $stream = shift;

            $stream->follow_up('Test::Builder::Result::Bail' => sub {die $_[0]});
            $stream->follow_up('Test::Builder::Result::Plan' => sub {
                my $plan = shift;
                return unless $plan->directive;
                return unless $plan->directive eq 'SKIP';
                die $plan;
            });

            $stream->listen(INTERCEPTOR => sub {
                my ($item) = @_;
                push @results => $item;
            });
            $code->();
        });
        1;
    };
    my $error = $@;

    die $error unless $ok || (blessed($error) && $error->isa('Test::Builder::Result'));

    return \@results;
}

1;
