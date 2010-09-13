package Test::Builder2::HistoryStack::Role::NoHistory;

use Carp;
use Test::Builder2::Mouse::Role;

my @push_method_aliases = qw{
    add_test_history
    add_result
    add_results
};

requires qw{results};
requires @push_method_aliases;

around \@push_method_aliases => sub{
    my $next = shift;
    my $self = shift;
    $self->$next(); # strip @_ from the call
    return $self->results; #pretend like we did something
};

=head1 NAME

Test::Builder2::HistoryStack::Role::NoHistory - Don't store the history stack

=head1 SYNOPSIS

    use Test::Builder2::HistoryStack;
    Test::Builder2::HistoryStack::Role::NoHistory->meta->apply($history);


=head1 DESCRIPTION

This object stores and manages the history of test results.

=head1 METHOD MODIFICATION

=cut


1;
