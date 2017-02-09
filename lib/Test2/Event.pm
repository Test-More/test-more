package Test2::Event;
use strict;
use warnings;

our $VERSION = '1.302078';

use Carp();
use Scalar::Util();

use Test2::Util();
use Test2::EventFacet::Info();
use Test2::EventFacet::Trace();
use Test2::EventFacet::Amnesty();

use Test2::Util::ExternalMeta qw/meta get_meta set_meta delete_meta/;

use Test2::Util::HashBase(
    # Identity
    qw{^trace nested in_nest},

    # Hub info
    qw{-terminate -global -causes_fail},

    # Formatter info
    qw{-summary -gravity -no_debug -_gravity_recursion},

    qw{-_facets -_amnesty -_info -no_legacy_facets},
);

{
    my $ID = 1;
    sub GEN_UNIQUE_NEST_ID { join "-" => ('NEST-ID', time(), $$, Test2::Util::get_tid, $ID++) }
}

sub callback() { }

sub init {
    my $self = shift;
    $self->{+IN_NEST} ||= delete $self->{in_subtest} if defined $self->{in_subtest};
    $self->{+NO_LEGACY_FACETS} = 1 if ref($self) eq __PACKAGE__;
}

sub related {
    my $self = shift;
    my ($event) = @_;

    my $tracea = $self->trace  or return undef;
    my $traceb = $event->trace or return undef;

    my $siga = $tracea->signature or return undef;
    my $sigb = $traceb->signature or return undef;

    return 1 if $siga eq $sigb;
    return 0;
}

{
    no warnings 'redefine';

    sub no_legacy_facets {
        $_[0]->{+NO_LEGACY_FACETS} = 1 if ref($_[0]) eq __PACKAGE__;
        $_[0]->{+NO_LEGACY_FACETS};
    }

    sub causes_fail {
        my $self = shift;
        return $self->{+CAUSES_FAIL} if defined $self->{+CAUSES_FAIL};
        my $facets = $self->facets;

        return 1 if $facets->{stop};
        return 0 if $facets->{amnesty};
        return 0 unless $facets->{assert};
        return $facets->{assert}->pass;
    }

    sub gravity {
        my $self = shift;
        return $self->{+GRAVITY} if defined $self->{+GRAVITY};
        return 100 if $self->causes_fail;

        # For legacy reasons gravity is closely tied to the deprecated
        # 'diagnostics' and 'no_display' methods. The default implementations
        # of each will try to deduce their values from the other. This can
        # cause recursion if neither is set.
        unless($self->{+_GRAVITY_RECURSION} || ref($self) eq __PACKAGE__) {
            local $self->{+_GRAVITY_RECURSION} = 1;
            return 100 if $self->diagnostics;
            return -1  if $self->no_display;
        }

        return 0;
    }

    sub summary {
        my $self = shift;
        return $self->{+SUMMARY} if defined $self->{+SUMMARY};
        return ref($self);
    }
}

sub facets {
    my $self = shift;

    my %facets = $self->{+_FACETS} ? %{$self->{+_FACETS}} : ();

    push @{$facets{amnesty}} => @{$self->{+_AMNESTY}} if $self->{+_AMNESTY};
    push @{$facets{info}}    => @{$self->{+_INFO}} if $self->{+_INFO};

    unless ($self->{+NO_LEGACY_FACETS} || $self->no_legacy_facets) {
        my $mixin = $self->legacy_facets;

        # These facet types have more than 1 value
        push @{$facets{amnesty}} => @{delete $mixin->{amnesty}} if $mixin->{amnesty};
        push @{$facets{info}}    => @{delete $mixin->{info}}    if $mixin->{info};

        # Legacy is not used if the type is already set.
        $facets{$_} ||= $mixin->{$_} for keys %$mixin;
    }

    # The events trace always wins.
    $facets{trace} = $self->{+TRACE} if $self->{+TRACE};

    return \%facets;
}

sub add_info {
    my $self = shift;

    while (@_) {
        my $type = shift;

        if (Scalar::Util::blessed($type) && $type->isa('Test2::EventFacet::Info')) {
            push @{$self->{+_INFO}} => $type;
            next;
        }

        my $details = shift;
        push @{$self->{+_INFO}} => Test2::EventFacet::Info->new(
            type    => $type,
            details => $details,
        );
    }
}

sub add_amnesty {
    my $self = shift;

    while (@_) {
        my $am = shift;

        if (Scalar::Util::blessed($am) && $am->isa('Test2::EventFacet::Amnesty')) {
            push @{$self->{+_AMNESTY}} => $am;
        }

        my $details = shift;
        push @{$self->{+_AMNESTY}} => Test2::EventFacet::Amnesty->new(
            action => $am,
            details => $details,
        );
    }
}

sub legacy_facets {
    my $self = shift;

    # Prevent recursion that can occur if legacy_facets is requested on events
    # that do not override increments_count, sets_plan, or causes_fail.
    return {} if $self->{legacy_facets};
    local $self->{legacy_facets} = 1;

    # The facet generator only works on subclasses
    return if ref($self) eq __PACKAGE__;

    my $facets = {};

    if ($self->increments_count) {
        my $pass = $self->causes_fail ? 0 : 1;

        require Test2::EventFacet::Assert;
        $facets->{assert} = Test2::EventFacet::Assert->new(pass => $pass);
    }

    if (my @plan = $self->sets_plan) {
        require Test2::EventFacet::Plan;

        my %attrs = (count => $plan[0]);

        $attrs{details} = $plan[2] if defined $plan[2];

        if ($plan[1]) {
            $attrs{skip} = 1 if $plan[1] eq 'SKIP';
            $attrs{none} = 1 if $plan[1] eq 'NO PLAN';
        }

        $facets->{plan} = Test2::EventFacet::Plan->new(%attrs);
    }

    return $facets;
}

# JSON
###############
sub from_json {
    my $class = shift;
    my %p     = @_;

    my $event_pkg = delete $p{'__PACKAGE__'};
    require(Test2::Util::pkg_to_file($event_pkg));

    if (exists $p{trace}) {
        $p{trace} = Test2::EventFacet::Trace->from_json(%{$p{trace}});
    }

    die "TODO: Unserialize facets";

    return $event_pkg->new(%p);
}

{
    no warnings 'once';
    *to_json = \&TO_JSON;
}
sub TO_JSON {
    my $self = shift;

    my %overrides = @_;

    return {
        %$self,
        __PACKAGE__ => ref($self),

        Test2::Util::ExternalMeta::META_KEY() => undef,

        %overrides,
    };
}

   #############################
#   ##                       ##   #
#####  DEPRECATED BELOW HERE  #####
#   ##                       ##   #
   #############################

Test2::Util::deprecate_quietly( qw{ in_subtest set_in_subtest });

sub in_subtest     { $_[0]->in_nest }
sub set_in_subtest { $_[0]->set_in_nest($_[1]) }

sub no_display  { $_[0]->gravity < 0 ? 1 : 0 }
sub diagnostics { $_[0]->gravity > 0 ? 1 : 0 }

sub increments_count { $_[0]->facets->{assert} ? 1 : 0 }

sub sets_plan {
    my $self = shift;
    my $plan = $self->facets->{plan} or return;

    return ($plan->count || 0, 'SKIP',    $plan->details) if $plan->skip;
    return ($plan->count || 0, 'NO PLAN', $plan->details) if $plan->none;
    return ($plan->count);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event - Base class for events

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test2>.

=head1 EVENT API

TODO

=head1 THIRD PARTY META-DATA

This object consumes L<Test2::Util::ExternalMeta> which provides a consistent
way for you to attach meta-data to instances of this class. This is useful for
tools, plugins, and other extensions.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
