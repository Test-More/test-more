package Test2::API::InterceptResult;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Storable qw/dclone/;
use Carp qw/croak/;

use Test2::API::InterceptResult::Squasher;
use Test2::API::InterceptResult::Event;
use Test2::API::InterceptResult::Hub;

sub new {
    my $class = shift;
    bless([@_], $class);
}

sub new_from_ref { bless($_[1], $_[0]) }

sub clone { blessed($_[0])->new(@{$_[0]}) }

sub event_list { @{$_[0]} }

sub _upgrade {
    my $self = shift;
    my ($event) = @_;

    my $blessed = blessed($event);

    return $event if $blessed && $event->isa('Test2::API::InterceptResult::Event');

    my $fd = dclone($blessed ? $event->facet_data : $event);

    my $class = blessed($self);

    if (my $parent = $fd->{parent}) {
        $parent->{children} = $class->new_from_ref($parent->{children} || [])->upgrade;
    }

    return Test2::API::InterceptResult::Event->new(facet_data => $fd, result_class => $class);
}

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

    my @out = map { $self->_upgrade($_) } @$self;

    return blessed($self)->new_from_ref(\@out) if defined wantarray;

    @$self = @out;
}

sub squash_diag {
    my $self = shift;

    my @output;

    my $squasher = Test2::API::InterceptResult::Squasher->new(events => \@output);
    $squasher->process($self->_upgrade($_)) for @$self;
    $squasher->flush_down();
    $squasher = undef;

    return blessed($self)->new_from_ref(\@output);
}

sub flatten         { shift->map(flatten        => @_) }
sub briefs          { shift->map(brief          => @_) }
sub summaries       { shift->map(summary        => @_) }
sub subtest_results { shift->map(subtest_result => @_) }

sub asserts  { shift->grep(assert  => @_) }
sub subtests { shift->grep(subtest => @_) }
sub diags    { shift->grep(diags   => @_) }
sub notes    { shift->grep(notes   => @_) }
sub errors   { shift->grep(errors  => @_) }
sub plans    { shift->grep(plan    => @_) }

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
    my ($call, @args) = @_;
    blessed($self)->new_from_ref([grep { $self->_upgrade($_)->$call(@args) } @$self]);
};

1;
