package Test2::API::InterceptResult;
use strict;
use warnings;

use List::Util qw/first/;
use Scalar::Util qw/blessed/;
use Storable qw/dclone/;

use Test2::API::InterceptResult::Event;

use Test2::Util::HashBase qw{
    +hub +subtest_event

    <raw_events <context


    <state

    +squash_diag

    +subtest_results

    +events
    +asserts
    +subtests
    +diags
    +notes
    +errors
    +plan
};

sub init {
    my $self = shift;

    $self->{+SQUASH_DIAG} = 1 unless defined $self->{+SQUASH_DIAG};

    if (my $hub = $self->{+HUB}) {
        $self->{+STATE} ||= $hub->state;
    }
    elsif (my $se = $self->{+SUBTEST_EVENT}) {
        $self->{+STATE}      ||= $se->{state};
        $self->{+RAW_EVENTS} ||= $se->{children};
    }

    $self->{+STATE} ||= {};

    my $raw_events = $self->{+RAW_EVENTS} ||= [];
}

sub squash_diag {
    my $self = shift;
    return $self->{+SQUASH_DIAG} unless @_;

    my $old = $self->{+SQUASH_DIAG};
    my ($new) = @_;

    # No change if it was true and is true again or false and false again
    return if $old && $new;
    return if !$old && !$new;

    delete $self->{$_} for EVENTS, ASSERTS, SUBTESTS, DIAGS, NOTES, ERRORS, PLAN;

    return $self->{+SQUASH_DIAG} = $new;
}

sub events {
    my $self = shift;
    return @{$self->{+EVENTS} ||= $self->_upgrade_events($self->{+RAW_EVENTS})};
}

sub _upgrade_events {
    my $self = shift;
    my ($raw_events) = @_;

    my @events;
    my ($merge, $msig, $clear_merge);
    for my $raw (@$raw_events) {
        my $fd = dclone(blessed($raw) ? $raw->facet_data : $raw);

        push @events => Test2::API::InterceptResult::Event->new(facet_data => $fd);

        if (my $parent = $fd->{parent}) {
            $parent->{children} = $self->_upgrade_events($parent->{children} || []);
        }

        next unless $self->{+SQUASH_DIAG};
        ($merge, $msig) = () if $clear_merge;

        unless ($merge) {
            next unless $fd->{assert} && !$fd->{assert}->{pass};

            $msig = Test2::EventFacet::Trace::signature($fd) or next;

            $merge       = $fd;
            $clear_merge = 0;

            next;
        }

        $clear_merge = 1;

        # Only merge into matching trace signatres
        my $esig = Test2::EventFacet::Trace::signature($fd);
        next unless $esig && $esig eq $msig;

        # Do not merge up if one of these facets is present.
        next if first { defined $fd->{$_} } qw/assert control errors plan/;

        my @info = @{$fd->{info} || []};

        # no info, no merge
        next unless @info;

        # non-diag info, no merge
        next if first { !$_->{tag} || uc($_->{tag}) ne 'DIAG' } @info;

        # OK Merge! Do not clear merge in case the next event is also a matching sig diag-only
        $clear_merge = 0;
        push @{$merge->{info}}        => @{$fd->{info}};
        push @{$merge->{merged_from}} => $fd;
    }

    return \@events;
}

sub subtest_results {
    my $self = shift;

    my $class = blessed($self);

    my $results = $self->{+SUBTEST_RESULTS} ||= [
        map { $_->is_subtest ? $class->new(subtest_event => $_) : () } $self->events,
    ];

    return @{$results};
}

sub event_briefs { map { $_->brief } $_[0]->events }

sub event_summaries {
    my $self = shift;
    my %params = @_;

    # Order matters
    my @try = ('summary');
    unshift @try => 'assert_summary'  if $params{expand_asserts};
    unshift @try => 'subtest_summary' if $params{expand_subtests};

    my @out;

    for my $event ($self->events) {
        push @out => first { $event->$_ } @try;
    }

    return @out;
}

sub subtest_summaries { map { $_->subtest_summary } $_[0]->subtests }

sub assert_summaries {
    my $self = shift;
    my %params = @_;

    return map { $_->assert_summary } $self->asserts
        unless $params{expand_subtests};

    return map { $_->subtest_summary || $_->assert_summary } $self->asserts;
}

sub asserts  { @{$_[0]->{+ASSERTS}  ||= [map  { $_->assert  }         $_[0]->events]} }
sub subtests { @{$_[0]->{+SUBTESTS} ||= [map  { $_->subtest }         $_[0]->events]} }
sub diags    { @{$_[0]->{+DIAGS}    ||= [map  { $_->diags   }         $_[0]->events]} }
sub notes    { @{$_[0]->{+NOTES}    ||= [map  { $_->notes   }         $_[0]->events]} }
sub errors   { @{$_[0]->{+ERRORS}   ||= [map  { $_->errors  }         $_[0]->events]} }
sub plan     { $_[0]->{+PLAN}       ||= first { $_->plan    } reverse $_[0]->events   }

sub diag_messages  { map { $_->{details} } $_[0]->diags  }
sub note_messages  { map { $_->{details} } $_[0]->notes  }
sub error_messages { map { $_->{details} } $_[0]->errors }

# state delegation
sub assert_count { $_[0]->{+STATE}->{count} }
sub bailed_out   { $_[0]->{+STATE}->{bailed_out} }
sub failed_count { $_[0]->{+STATE}->{failed} }
sub follows_plan { $_[0]->{+STATE}->{follows_plan} }
sub is_passing   { $_[0]->{+STATE}->{is_passing} }
sub nested       { $_[0]->{+STATE}->{nested} }
sub skipped      { $_[0]->{+STATE}->{skip_reason} }


1;
