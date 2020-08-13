package Test2::API::InterceptResult;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test2::Util  qw/pkg_to_file/;
use Storable     qw/dclone/;
use Carp         qw/croak confess/;

use Test2::API::InterceptResult::Squasher;
use Test2::API::InterceptResult::Event;
use Test2::API::InterceptResult::Hub;


sub new {
    confess "Called a method that creates a new instance in void context" unless defined wantarray;
    my $class = shift;
    bless([@_], $class);
}

sub new_from_ref {
    confess "Called a method that creates a new instance in void context" unless defined wantarray;
    bless($_[1], $_[0]);
}

sub clone { blessed($_[0])->new(@{dclone($_[0])}) }

sub event_list { @{$_[0]} }

sub _upgrade {
    my $self = shift;
    my ($event, %params) = @_;

    my $blessed = blessed($event);

    my $upgrade_class = $params{upgrade_class} ||= 'Test2::API::InterceptResult::Event';

    return $event if $blessed && $event->isa($upgrade_class);

    my $fd = dclone($blessed ? $event->facet_data : $event);

    my $class = $params{result_class} ||= blessed($self);

    if (my $parent = $fd->{parent}) {
        $parent->{children} = $class->new_from_ref($parent->{children} || [])->upgrade(%params);
    }

    my $uc_file = pkg_to_file($upgrade_class);
    require($uc_file) unless $INC{$uc_file};
    return $upgrade_class->new(facet_data => $fd, result_class => $class);
}

sub hub {
    my $self = shift;

    my $hub = Test2::API::InterceptResult::Hub->new();
    $hub->process($_) for @$self;
    $hub->set_ended(1);

    return $hub;
}

sub state {
    my $self = shift;
    my %params = @_;

    my $hub = $self->hub;

    my $out = {
        map {($_ => scalar $hub->$_)} qw/count failed is_passing plan bailed_out skip_reason/
    };

    $out->{bailed_out} = $self->_upgrade($out->{bailed_out}, %params)->bailout_reason || 1
        if $out->{bailed_out};

    $out->{follows_plan} = $hub->check_plan;

    return $out;
}

sub upgrade {
    my $self = shift;
    my %params = @_;

    my @out = map { $self->_upgrade($_, %params) } @$self;

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
        $squasher->process($self->_upgrade($_, %params)->clone) for @$self;
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

sub diag_messages  {   shift->diags(@_)->map(sub { $_->diag_messages  }, @_) }
sub note_messages  {   shift->notes(@_)->map(sub { $_->note_messages  }, @_) }
sub error_messages {  shift->errors(@_)->map(sub { $_->error_messages }, @_) }

no warnings 'once';

*map = sub {
    my $self = shift;
    my ($call, %params) = @_;

    my $args = $params{args} ||= [];

    return [map { local $_ = $self->_upgrade($_, %params); $_->$call(@$args) } @$self];
};

*grep = sub {
    my $self = shift;
    my ($call, %params) = @_;

    my $args = $params{args} ||= [];

    my @out = grep { local $_ = $self->_upgrade($_, %params); $_->$call(@$args) } @$self;

    return blessed($self)->new_from_ref(\@out)
        unless $params{in_place};

    @$self = @out;
    return $self;
};

1;
