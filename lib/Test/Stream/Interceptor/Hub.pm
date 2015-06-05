package Test::Stream::Interceptor::Hub;
use strict;
use warnings;

use Test::Stream::Interceptor::Terminator;

use base 'Test::Stream::Hub';

sub terminate {
    my $self = shift;
    my ($code) = @_;
    die bless(\$code, 'Test::Stream::Interceptor::Terminator');
}

1;
