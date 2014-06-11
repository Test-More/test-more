package Test::Builder::Formatter::TAP;
use strict;
use warnings;

use parent 'Test::Builder::Formatter';

# The default 6 result types all have a to_tap method.
for my $handler (qw/ok diag note plan bail nest/) {
    my $sub = sub {
        my $self = shift;
        my ($tb, $item) = @_;
        $tb->_print($item->to_tap);
    };
    no strict 'refs';
    *$handler = $sub;
}

1;
