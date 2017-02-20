package Test2::Event::Diag;
use strict;
use warnings;

our $VERSION = '1.302078';

use Test2::EventFacet::Info;

BEGIN { require Test2::Event; our @ISA = qw(Test2::Event) }
use Test2::Util::HashBase qw/message/;

sub terminate        () { }
sub sets_plan        () { }
sub no_legacy_facets () { 1 }
sub no_debug         () { 1 }
sub diagnostics      () { 1 }
sub global           () { 0 }
sub increments_count () { 0 }
sub no_display       () { 0 }
sub causes_fail      () { 0 }
sub gravity          { $_[0]->{+_AMNESTY} ? 0 : 100 }

sub summary { $_[0]->{+MESSAGE} }

sub init {
    $_[0]->{+MESSAGE} = 'undef' unless defined $_[0]->{+MESSAGE};
    $_[0]->{+NO_LEGACY_FACETS} = 1;
}

sub facets {
    my $self = shift;

    my $facets = $self->SUPER::facets();

    push @{$facets->{info}} => Test2::EventFacet::Info->new(
        tag     => 'diag',
        details => $self->{+MESSAGE},
    );

    return $facets;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Diag - Diag event type

=head1 DESCRIPTION

Diagnostics messages, typically rendered to STDERR.

=head1 SYNOPSIS

    use Test2::API qw/context/;
    use Test2::Event::Diag;

    my $ctx = context();
    my $event = $ctx->diag($message);

=head1 ACCESSORS

=over 4

=item $diag->message

The message for the diag.

=back

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
