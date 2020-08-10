use strict;
use warnings;

use Test2::Tools::Tiny;
use Test2::API::InterceptResult;

my $CLASS = 'Test2::API::InterceptResult';

ok($CLASS->can($_), "have sub '$_'") for qw/raw_events context state/;

tests init => sub {
    my $one = $CLASS->new();
    ok($one->isa($CLASS), "Got an instance");
    ok($one->squash_info, "squash_info is on by default");
    is_deeply($one->state, {}, "Got a sane default state (empty hashref)");
    is_deeply($one->raw_events, [], "Got a sane default raw_events (empty arrayref)");

    no warnings 'once';
    local *HUB::state = sub { {state => 'yes'} };

    my $two = $CLASS->new(hub => bless({}, 'HUB'));
    is_deeply($two->state, {state => 'yes'}, "Got state from hub");

    my $se = Test2::API::InterceptResult::Event->new(facet_data => {
        parent => {
            children => ['not a valid event'],
            state => { subtest => 'state' },
            hid => 'uhg',
        },
    });

    my $three = $CLASS->new(subtest_event => $se);
    is_deeply($three->state, { subtest => 'state' }, "Got state from subtest event");
    is_deeply($three->raw_events, ['not a valid event'], "Got raw events from subtest event");

    like(
        exception { $CLASS->new(subtest_event => Test2::API::InterceptResult::Event->new()) },
        qr/not a subtest event/,
        "subtest_event must be valid"
    );
};

tests squash_info => sub {
    my $one = $CLASS->new();
    is($one->squash_info, 1, "Defaults to 1");

    my $two = $CLASS->new(squash_info => 0);
    is($two->squash_info, 0, "Can set at construction");

    my @clear = qw{ events asserts subtests diags notes errors plans subtest_results };

    $two->{$_} = 1 for @clear;
    is($two->squash_info(1), 1, "Can change to on");
    ok(!$two->{$_}, "Cleared $_") for @clear;

    $two->{$_} = 1 for @clear;
    is($two->squash_info(1), 1, "no change");
    ok($two->{$_}, "Did not clear $_ without change") for @clear;

    $two->{$_} = 1 for @clear;
    is($two->squash_info(0), 0, "Can change to off");
    ok(!$two->{$_}, "Cleared $_") for @clear;

    $two->{$_} = 1 for @clear;
    is($two->squash_info(0), 0, "no change");
    ok($two->{$_}, "Did not clear $_ without change") for @clear;
};

done_testing;

__END__

sub upgrade_events {
    my $self = shift;
    my ($raw_events, %params) = @_;

    my (@events, $squasher);

    if ($self->{+SQUASH_INFO}) {
        $squasher = Test2::API::InterceptResult::Squasher->new(events => \@events);
    }

    for my $raw (@$raw_events) {
        my $fd = dclone(blessed($raw) ? $raw->facet_data : $raw);

        my $event = Test2::API::InterceptResult::Event->new(facet_data => $fd, result_class => blessed($self));

        if (my $parent = $fd->{parent}) {
            $parent->{children} = $self->upgrade_events($parent->{children} || []);
        }

        if ($squasher) {
            $squasher->process($event);
        }
        else {
            push @events => $event;
        }
    }

    $squasher->flush_down() if $squasher;

    return \@events;
}

sub flatten         {[ map { $_->flatten(@_) } @{shift->events} ]}
sub event_briefs    {[ map { $_->brief }       @{$_[0]->events} ]}
sub event_summaries {[ map { $_->summary }     @{$_[0]->events} ]}

sub subtest_results { $_[0]->{+SUBTEST_RESULTS} ||= [ map { $_->subtest_result } @{$_[0]->subtests} ] }

sub events   { $_[0]->{+EVENTS}   ||= $_[0]->upgrade_events($_[0]->{+RAW_EVENTS}) }
sub asserts  { $_[0]->{+ASSERTS}  ||= [grep { $_->assert  } @{$_[0]->events}]     }
sub subtests { $_[0]->{+SUBTESTS} ||= [grep { $_->subtest } @{$_[0]->events}]     }
sub diags    { $_[0]->{+DIAGS}    ||= [grep { $_->diags   } @{$_[0]->events}]     }
sub notes    { $_[0]->{+NOTES}    ||= [grep { $_->notes   } @{$_[0]->events}]     }
sub errors   { $_[0]->{+ERRORS}   ||= [grep { $_->errors  } @{$_[0]->events}]     }
sub plans    { $_[0]->{+PLANS}    ||= [grep { $_->plan    } @{$_[0]->events}]     }

sub diag_messages  {[ map { $_->{details} } @{$_[0]->diags}  ]}
sub note_messages  {[ map { $_->{details} } @{$_[0]->notes}  ]}
sub error_messages {[ map { $_->{details} } @{$_[0]->errors} ]}

# state delegation
sub assert_count { $_[0]->{+STATE}->{count} }
sub bailed_out   { $_[0]->{+STATE}->{bailed_out} }
sub failed_count { $_[0]->{+STATE}->{failed} }
sub follows_plan { $_[0]->{+STATE}->{follows_plan} }
sub is_passing   { $_[0]->{+STATE}->{is_passing} }
sub nested       { $_[0]->{+STATE}->{nested} }
sub skipped      { $_[0]->{+STATE}->{skip_reason} }

1;
