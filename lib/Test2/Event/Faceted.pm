package Test2::Event::Faceted;
use strict;
use warnings;

our $VERSION = '1.302077';

BEGIN { require Test2::Event; our @ISA = qw(Test2::Event) }
use Test2::Util::HashBase;

use Scalar::Util();

require Test2::EventFacet::Amnesty;
require Test2::EventFacet::Assert;
require Test2::EventFacet::Info;
require Test2::EventFacet::Nest;
require Test2::EventFacet::Plan;
require Test2::EventFacet::Stop;
require Test2::EventFacet::Trace;

sub no_legacy_facets() { 1 }

my %AUTO_FACET = (
    assert => 'Test2::EventFacet::Assert',
    nest   => 'Test2::EventFacet::Nest',
    plan   => 'Test2::EventFacet::Plan',
    stop   => 'Test2::EventFacet::Stop',

    # These get handled differently.
    # info => 'Test2::EventFacet::info',
    # info => 'Test2::EventFacet::amnesty',
);

sub init {
    my $self = shift;

    $self->{+_FACETS} ||= delete $self->{facets}
        if $self->{facets};

    $self->{+TRACE} ||= $self->{+_FACETS}->{trace}
        if $self->{+_FACETS}->{trace};

    if (my $info = delete $self->{info}) {
        $self->add_info(@$info);
    }

    if (my $amnesty = delete $self->{amnesty}) {
        $self->add_amnesty(@$amnesty);
    }

    for my $facet (sort keys %AUTO_FACET) {
        my $raw = delete $self->{$facet} or next;
        my $class = $AUTO_FACET{$facet};
        my $isa = Scalar::Util::blessed($raw) && $raw->isa($class);
        $self->{+_FACETS}->{$facet} = $isa ? $raw : $class->new(%$raw);
    }
}

sub gravity {
    my $self = shift;
    return $self->{+GRAVITY} if defined $self->{+GRAVITY};
    return 100 if $self->causes_fail;
    return 0;
}

sub facets {
    my $self = shift;

    my %facets = $self->{+_FACETS} ? %{$self->{+_FACETS}} : ();

    push @{$facets{amnesty}} => @{$self->{+_AMNESTY}} if $self->{+_AMNESTY};
    push @{$facets{info}}    => @{$self->{+_INFO}}    if $self->{+_INFO};

    # The events trace always wins.
    $facets{trace} = $self->{+TRACE} if $self->{+TRACE};

    return \%facets;
}

sub summary {
    my $self = shift;

    my $f = $self->facets;

    my @parts;

    push @parts => 'ASSERT(' . ($f->{assert}->{pass} ? 'PASS' : 'FAIL') . ')'
        if $f->{assert};

    my %seen;
    push @parts => 'AMNESTY(' . (
        join ' ' => reverse sort grep { !$seen{$_}++ } map { defined $_->{action} && length $_->{action} ? $_->{action} : '...' } @{$f->{amnesty}}
    ) . ')'  if $f->{amnesty};

    push @parts => 'PLAN(' . ( $f->{plan}->{skip} ? 'SKIP' : $f->{plan}->{none} ? 'NONE': $f->{plan}->{count} || 0 ) . ')'
        if $f->{plan};

    %seen = (assert => 1, amnesty => 1, plan => 1, trace => 1);
    push @parts => map { $seen{$_}++ ? () : uc($_)} sort keys %$f;

    return 'EVENT' unless @parts;
    return 'EVENT: ' . join(' ', @parts);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Faceted

=head1 DESCRIPTION

    my $e = Test2::Event::Faceted->new(
        # Identity info:
        trace   => Test2::EventFacet::Trace->new(...),
        nested  => $depth,    # How deeply nested the event is
        in_nest => $nest_id,  # Parent nest id

        # Hub info
        terminate   => undef, # A defined value means exit the test
        global      => $bool, # You probably do not need this.
        causes_fail => $bool, # Override, default is to look at assert and amnesty

        # Formatter info
        summary  => $string,  # Override, default is a list of facets
        gravity  => $integer, # -1 means no display, 0 is normal >0 is important
        no_debug => $bool,    # True prevents diagnostics from being automatically added on assert failure.

        # Facets

        assert => {pass  => 1, details => 'xxx'},
        plan   => {count => 2, details => 'foo', skip => 0},

        info => [
            diag => 'xxx',
            diag => 'yyy',
        ],

        amnesty => [
            TODO => 'The test is a todo',
            skip => 'The test was skipped',
        ],

        stop => {detail => 'Bail out!!!!'},

        nest => {
            id       => 'subtest 42',
            buffered => 1,
            events   => [...],
        }
    );


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
