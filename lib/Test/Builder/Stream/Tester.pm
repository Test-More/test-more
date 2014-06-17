package Test::Builder::Stream::Tester;
use strict;
use warnings;

use Exporter qw/import/;

use parent 'Test::Builder::Formatter';

our @EXPORT = qw/intercept/;

sub intercept(&) {
    my ($code) = @_;
    require Test::Builder;
    my $TB = Test::Builder->new;

    my @results;
    my $restore = $TB->intercept;

    my $orig_bail = $TB->bailout_behavior;
    $TB->bailout_behavior(sub {
        my $bail = @_;
        die $bail->reason;
    });

    my $ok = eval {
        $TB->listen(INTERCEPTOR => sub {
            my ($item) = @_;
            push @results => $item;
            if ($item->isa('Test::Builder::Result::Ok')) {
                $TB->tests_run(-1);
                $TB->tests_failed(-1) unless $item->bool;
            }
        });
        $code->();
        1;
    };
    my $error = $@;

    $restore->();
    $TB->bailout_behavior($orig_bail);

    die $error unless $ok;

    return \@results;
}

1;
