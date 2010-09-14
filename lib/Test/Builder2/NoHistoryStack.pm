package Test::Builder2::NoHistoryStack;
use Carp;
use Test::Builder2::Mouse;
extends qw{Test::Builder2::HistoryStack};

=head1 NAME

Test::Builder2::NoHistoryStack - Store no history, just keep stats

=head1 SYNOPSIS

    use Test::Builder2::NoHistoryStack;

    # This is a shared singleton object
    my $history = Test::Builder2::NoHistoryStack->singleton;
    my $result  = Test::Builder2::Result->new_result( pass => 1 );

    $history->add_test_history( $result );
    $history->is_passing;
    $history->test_count;    # 1  we've seen a test
    $history->results_count; # 0  we did not store a result
    $history->results;       # [] still not there

=head1 DESCRIPTION

This object does not store results but manages the history of test stats.

=head1 API

All methods are the same from Test::Builder2::HistoryStack.

=cut

has '+results' => 
    lazy => 1,
    clearer => 'clear_results', 
;


after results_push => sub{
    shift->clear_results;
};


no Test::Builder2::Mouse;
1;

