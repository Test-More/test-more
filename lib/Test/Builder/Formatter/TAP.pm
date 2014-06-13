package Test::Builder::Formatter::TAP;
use strict;
use warnings;

use parent 'Test::Builder::Formatter';

# The default 6 result types all have a to_tap method.
for my $handler (qw/ok plan bail nest/) {
    my $sub = sub {
        my $self = shift;
        my ($tb, $item) = @_;
        $tb->_print($item->to_tap);
    };
    no strict 'refs';
    *$handler = $sub;
}

sub diag {
    my $self = shift;
    my ($tb, $item) = @_;

    return if $tb->no_diag;

    # Prevent printing headers when compiling (i.e. -c)
    return if $^C;

    $tb->_print_to_fh( $tb->_diag_fh, $item->to_tap );
}

sub note {
    my $self = shift;
    my ($tb, $item) = @_;

    return if $tb->no_diag;

    # Prevent printing headers when compiling (i.e. -c)
    return if $^C;

    $tb->_print_to_fh( $tb->output, $item->to_tap );
}

1;
