package Test::Builder::Stream::Tester;
use strict;
use warnings;

use Test::Builder::Stream;

use Exporter qw/import/;

use parent 'Test::Builder::Formatter';

our @EXPORT = qw/intercept/;

sub intercept(&) {
    my ($code) = @_;

    my @results;

    require Test::Builder;
    my $TB = Test::Builder->new;
    my $orig_bail = $TB->bailout_behavior;
    $TB->bailout_behavior(sub {
        my $bail = @_;
        die $bail->reason;
    });

    local $@;
    my $ok = eval {
        Test::Builder::Stream->intercept(sub {
            my $stream = shift;
            $stream->listen(INTERCEPTOR => sub {
                my ($item) = @_;
                push @results => $item;
            });
            $code->();
        });
        1;
    };
    my $error = $@;

    $TB->bailout_behavior($orig_bail);

    die $error unless $ok;

    return \@results;
}

1;
