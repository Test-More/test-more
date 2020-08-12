use strict;
use warnings;

use Test2::Tools::Tiny qw/tests exception/;
use Test2::V0;
use Test2::API::InterceptResult;
use Scalar::Util qw/reftype/;

*is_deeply = \&is;

my $CLASS = 'Test2::API::InterceptResult';

tests construction => sub {
    my $one = $CLASS->new('a');
    ok($one->isa($CLASS), "Got an instance");
    is(reftype($one), 'ARRAY', "Blessed arrayref");
    is_deeply($one, ['a'], "Ref looks good.");

    my $two = $CLASS->new_from_ref(['a']);
    ok($two->isa($CLASS), "Got an instance");
    is(reftype($two), 'ARRAY', "Blessed arrayref");
    is_deeply($two, ['a'], "Ref looks good.");

    my $three = $two->clone;
    ok($three->isa($CLASS), "Got an instance");
    is(reftype($three), 'ARRAY', "Blessed arrayref");
    is_deeply($three, ['a'], "Ref looks good.");

    push @$two => 'b';
    is_deeply($two, ['a', 'b'], "Modified two");
    is_deeply($three, ['a'], "three was not changed");
};

tests event_list => sub {
    my $one = $CLASS->new('a', 'b');
    is_deeply([$one->event_list], ['a', 'b'], "event_list is essentially \@{\$self}");
};

tests _upgrade => sub {
    require Test2::Event::Pass;
    my $event = Test2::Event::Pass->new(name => 'soup for you', trace => {frame => ['foo', 'foo.pl', 42]});
    ok($event->isa('Test2::Event'), "Start with an event");

    my $one = $CLASS->new;
    my $up = $one->_upgrade($event);
    ok($up->isa('Test2::API::InterceptResult::Event'), "Upgraded the event");
    is($up->result_class, $CLASS, "set the result class");

    is_deeply($event->facet_data, $up->facet_data, "Facet data is identical");

    $up->facet_data->{trace}->{frame}->[2] = 43;
    is($up->trace_line, 43, "Modified the facet data in the upgraded clone");
    is($event->facet_data->{trace}->{frame}->[2], 42, "Did nto modify the original");

    my $up2 = $one->_upgrade($up);
    is("$up2", "$up", "Returned the ref unmodified because it is already an upgraded item");

    require Test2::Event::V2;
    my $subtest = 'Test2::Event::V2'->new(
        trace => {frame => ['foo', 'foo.pl', 42]},
        assert => {pass => 1, details => 'pass'},
        parent => {
            hid => 1,
            children => [ $event ],
        },
    );

    my $subup = $one->_upgrade($subtest);
    ok($subup->the_subtest->{children}->isa($CLASS), "Blessed subtest subevents");
    ok(
        $subup->the_subtest->{children}->[0]->isa('Test2::API::InterceptResult::Event'),
        "Upgraded the children"
    );
};

done_testing;


__END__

sub hub {
    my $self = shift;

    my $hub = Test2::API::InterceptResult::Hub->new();
    $hub->process($_) for @$self;
    $hub->set_ended(1);
    $hub->set__plan('NO PLAN') unless $hub->_plan;

    return $hub;
}

sub state {
    my $self = shift;

    my $hub = $self->hub;

    my $out = {
        map {($_ => scalar $hub->$_)} qw/count failed is_passing plan bailed_out skip_reason/
    };

    $out->{follows_plan} = $hub->check_plan;

    return $out;
}

sub upgrade {
    my $self = shift;
    my %params = @_;

    my @out = map { $self->_upgrade($_) } @$self;

    return blessed($self)->new_from_ref(\@out)
        unless $params{in_place};

    @$self = @out;
    return $self;
}

sub squash_info {
    my $self = shift;
    my %params = @_;

    my @out;

    {
        my $squasher = Test2::API::InterceptResult::Squasher->new(events => \@out);
        # Clone to make sure we do not indirectly modify an existing one if it
        # is already upgraded
        $squasher->process($self->_upgrade($_)->clone) for @$self;
        $squasher->flush_down();
    }

    return blessed($self)->new_from_ref(\@out)
        unless $params{in_place};

    @$self = @out;
    return $self;
}

sub asserts  { shift->grep(assert  => @_) }
sub subtests { shift->grep(subtest => @_) }
sub diags    { shift->grep(diags   => @_) }
sub notes    { shift->grep(notes   => @_) }
sub errors   { shift->grep(errors  => @_) }
sub plans    { shift->grep(plan    => @_) }

sub flatten         { shift->map(flatten        => @_) }
sub briefs          { shift->map(brief          => @_) }
sub summaries       { shift->map(summary        => @_) }
sub subtest_results { shift->map(subtest_result => @_) }

sub diag_messages { shift->diags(@_)->map(sub { $_->{details} }, @_) }
sub note_messages { shift->notes(@_)->map(sub { $_->{details} }, @_) }
sub error_messages { shift->errors(@_)->map(sub { $_->{details} }, @_) }

no warnings 'once';

*map = sub {
    my $self = shift;
    my ($call, @args) = @_;
    return [map { $self->_upgrade($_)->$call(@args) } @$self];
};

*grep = sub {
    my $self = shift;
    my ($call, %params) = @_;

    my $args = $params{args} || [];
    my @out = grep { $self->_upgrade($_)->$call(@$args) } @$self;

    blessed($self)->new_from_ref(\@out)
        unless $params{in_place};

    @$self = @out;
    return $self;
};

1;
