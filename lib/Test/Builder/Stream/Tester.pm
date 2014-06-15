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

    my @items;
    my $restore = $TB->intercept;
    my $ok = eval {
        $TB->listen(sub {
            my ($tb, $item) = @_;
            push @items => $item;
        });
        # I am not fond of this local, but it does the job.
        local $TB->{Curr_Test} = 0;
        $code->();
        1;
    };
    my $error = $@;
    $restore->();

    return { items => \@items, error => $error };
}

1;
