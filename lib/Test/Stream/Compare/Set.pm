package Test::Stream::Compare::Set;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/checks _reduction/],
);

use Test::Stream::Delta;

use Carp qw/croak confess/;
use Scalar::Util qw/reftype/;

sub init {
    my $self = shift;

    my $reduction = delete $self->{reduction} || 'any';

    $self->{+CHECKS} ||= [];

    $self->set_reduction($reduction);

    $self->SUPER::init();
}

sub name      { '<CHECK-SET>' }
sub operator  { $_[0]->{+_REDUCTION} }
sub reduction { $_[0]->{+_REDUCTION} }

my %VALID = (any => 1, all => 1, none => 1);
sub set_reduction {
    my $self = shift;
    my ($redu) = @_;

    croak "'$redu' is not a valid set reduction"
        unless $VALID{$redu};

    $self->{+_REDUCTION} = $redu;
}

sub verify {
    my $self = shift;
    my %params = @_;
    return $params{exists} ? 1 : 0;
}

sub add_check {
    my $self = shift;
    push @{$self->{+CHECKS}} => @_;
}

sub deltas {
    my $self = shift;
    my %params = @_;

    my $checks    = $self->{+CHECKS};
    my $reduction = $self->{+_REDUCTION};
    my $convert   = $params{convert};

    unless ($checks && @$checks) {
        my $file = $self->file;
        my $lines = $self->lines;

        my $extra = "";
        if ($file and $lines and @$lines) {
            my $lns = (@$lines > 1 ? 'lines ' : 'line ' ) .  join ', ', @$lines;
            $extra = " (Set defined in $file $lns)";
        }

        die "No checks defined for set$extra\n";
    }

    my @deltas;
    my $i = 0;
    for my $check (@$checks) {
        my $c = $convert->($check);
        my $id = [META => "Check " . $i++];
        my @d = $c->run(%params, id => $id);

        if ($reduction eq 'any') {
            return () unless @d;
            push @deltas => @d;
        }
        elsif ($reduction eq 'all') {
            push @deltas => @d;
        }
        elsif ($reduction eq 'none') {
            push @deltas => Test::Stream::Delta->new(
                verified => 0,
                id       => $id,
                got      => $params{got},
                check    => $c,
            ) unless @d;
        }
        else {
            die "Invalid reduction: $reduction\n";
        }
    }

    return @deltas;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Set - Allows a field to be matched against a set of
checks.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This module is used by the C<check_set> function in the
L<Test::Stream::Plugin::Compare> plugin.

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
