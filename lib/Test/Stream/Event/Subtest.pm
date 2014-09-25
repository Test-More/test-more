package Test::Stream::Event::Subtest;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test::Stream::Carp qw/confess/;
use Test::Stream qw/STATE_PASSING STATE_COUNT OUT_STD/;

use Test::Stream::Event(
    base      => 'Test::Stream::Event::Ok',
    accessors => [qw/state events exception/],
);

sub init {
    my $self = shift;

    $self->[REAL_BOOL] = $self->[STATE]->[STATE_PASSING] && $self->[STATE]->[STATE_COUNT];
    $self->[EVENTS] ||= [];

    if (my $le = $self->[EVENTS]->[-1]) {
        my $is_skip = $le->isa('Test::Stream::Event::Plan');
        $is_skip &&= $le->directive;
        $is_skip &&= $le->directive eq 'SKIP';

        if ($is_skip) {
            my $skip = 'all';
            $skip .= ": " . $le->reason if $le->reason;
            # Should be a snapshot now:
            $self->[CONTEXT]->set_skip($skip);
            $self->[REAL_BOOL] = 1;
        }

        $self->[EXCEPTION] = $le if $is_skip || $le->isa('Test::Stream::Event::Bail');
    }

    push @{$self->[DIAG]} => '  No tests run for subtest.'
        unless $self->[EXCEPTION] || $self->[STATE]->[STATE_COUNT];

    $self->SUPER::init();
}

sub to_tap {
    my $self = shift;
    my ($num, $delayed) = @_;

    unless($delayed) {
        return if $self->[EXCEPTION]
               && $self->[EXCEPTION]->isa('Test::Stream::Event::Bail');

        return $self->SUPER::to_tap($num);
    }

    # Subtest final result first
    $self->[NAME] =~ s/$/ {/mg;
    my @out = (
        $self->SUPER::to_tap($num),
        $self->_render_events(@_),
        [OUT_STD, "}\n"],
    );
    $self->[NAME] =~ s/ \{$//mg;
    return @out;
}

sub _render_events {
    my $self = shift;
    my ($num, $delayed) = @_;

    my $idx = 0;
    my @out;
    for my $e (@{$self->events}) {
        next unless $e->can('to_tap');
        $idx++ if $e->isa('Test::Stream::Event::Ok');
        push @out => $e->to_tap($idx, $delayed);
    }

    for my $set (@out) {
        $set->[1] =~ s/^/    /mg;
    }

    return @out;
}

1;

__END__

=encoding utf8

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

=over 4

=item Test::Stream

=item Test::Tester2

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
