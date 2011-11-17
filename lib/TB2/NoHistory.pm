package TB2::NoHistory;

use Carp;
use TB2::Mouse;
extends qw{TB2::History};

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::NoHistory - Store no history, just keep stats

=head1 SYNOPSIS

    use TB2::NoHistory;

    # This is a shared default object
    my $history = TB2::NoHistory->default;
    my $ec = TB2::EventCoordinator->create(
        history => $history
    );

    my $result  = TB2::Result->new_result( pass => 1 );
    $ec->post_event($result);

    $history->can_succeed;    # true
    $history->test_count;    # 1  we've seen a test
    $history->results_count; # 0  we did not store a result
    $history->results;       # [] still not there

=head1 DESCRIPTION

This object does not store results but manages the history of test stats.

=head1 API

All methods are the same from TB2::History.

=cut

has '+results' => 
    lazy => 1,
    clearer => 'clear_results', 
;


after results_push => sub{
    shift->clear_results;
};


no TB2::Mouse;
1;

