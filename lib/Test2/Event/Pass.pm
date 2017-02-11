package Test2::Event::Pass;
use strict;
use warnings;

our $VERSION = '1.302077';

use Test2::EventFacet::Assert;

BEGIN { require Test2::Event; our @ISA = qw(Test2::Event) }
use Test2::Util::HashBase qw/-assert/;

sub global()           { 0 }
sub causes_fail()      { 0 }
sub gravity()          { 0 }
sub no_legacy_facets() { 1 }
sub increments_count() { 1 }
sub terminate()        { }
sub sets_plan()        { }
sub callback()         { }
sub init()             { }

sub facets {
    my $self = shift;

    my %facets = (
        trace  => $self->{+TRACE},
        assert => $self->{+ASSERT},
    );

    # These might have been added after the fact...
    push @{$facets{amnesty}} => @{$self->{+_AMNESTY}} if $self->{+_AMNESTY};
    push @{$facets{info}}    => @{$self->{+_INFO}}    if $self->{+_INFO};

    return \%facets;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Pass - Optimized event subclass for the most common event situation.

=head1 DESCRIPTION

The vast majority of all events generated are a simple passing result. This
event subclass exists to bypass the overhead involved for other cases when we
are sure all we have is a passing event.

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
