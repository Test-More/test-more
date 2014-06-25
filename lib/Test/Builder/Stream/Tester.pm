package Test::Builder::Stream::Tester;
use strict;
use warnings;

use Test::Builder::Stream;

use Scalar::Util qw/blessed/;

use Test::Builder::Provider;
provides qw/intercept/;

sub intercept(&) {
    my ($code) = @_;

    my @results;

    local $@;
    my $ok = eval {
        Test::Builder::Stream->intercept(sub {
            my $stream = shift;
            $stream->exception_followup;

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

__END__

=head1 TEST COMPONTENT MAP

  [Test Script] > [Test Tool] > [Test::Builder] > [Test::Bulder::Stream] > [Result Formatter]
                                                                   \          /
                                                                   You are here

A test script uses a test tool such as L<Test::More>, which uses Test::Builder
to produce results. The results are sent to L<Test::Builder::Stream> which then
forwards them on to one or more formatters. The default formatter is
L<Test::Builder::Fromatter::TAP> which produces TAP output.



