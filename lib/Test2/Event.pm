package Test2::Event;
use strict;
use warnings;

our $VERSION = '1.302078';

use Test2::Util::HashBase qw/trace nested in_subtest subtest_id/;
use Test2::Util::ExternalMeta qw/meta get_meta set_meta delete_meta/;
use Test2::Util qw(pkg_to_file);
use Test2::Util::Trace;

sub causes_fail      { 0 }
sub increments_count { 0 }
sub diagnostics      { 0 }
sub no_display       { 0 }

sub callback { }

sub terminate { () }
sub global    { () }
sub sets_plan { () }

sub summary { ref($_[0]) }

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

sub from_json {
    my $class = shift;
    my %p     = @_;

    my $event_pkg = delete $p{__PACKAGE__};
    require(pkg_to_file($event_pkg));

    if (exists $p{trace}) {
        $p{trace} = Test2::Util::Trace->from_json(%{$p{trace}});
    }

    if (exists $p{subevents}) {
        my @subevents;
        for my $subevent (@{delete $p{subevents} || []}) {
            push @subevents, Test2::Event->from_json(%$subevent);
        }
        $p{subevents} = \@subevents;
    }

    return $event_pkg->new(%p);
}

sub TO_JSON {
    my $self = shift;
    return {%$self, Test2::Util::ExternalMeta::META_KEY() => undef, __PACKAGE__ => ref $self};
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
