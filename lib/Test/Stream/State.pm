package Test::Stream::State;
use strict;
use warnings;

use Test::Stream::HashBase(
    accessors => [qw{count failed _passing plan ended legacy}],
);

Test::Stream::Exporter->cleanup;

sub init {
    my $self = shift;

    $self->{+COUNT}    = 0 unless defined $self->{+COUNT};
    $self->{+FAILED}   = 0 unless defined $self->{+FAILED};
    $self->{+ENDED}    = 0 unless defined $self->{+ENDED};
    $self->{+_PASSING} = 1 unless defined $self->{+_PASSING};
}

sub reset {
    my $self = shift;

    delete $self->{+PLAN};
    delete $self->{+LEGACY};

    $self->{+COUNT}   = 0;
    $self->{+FAILED}  = 0;
    $self->{+ENDED}   = 0;
    $self->{+_PASSING} = 1;
}

sub is_passing {
    my $self = shift;

    ($self->{+_PASSING}) = @_ if @_;

    my $pass = $self->{+_PASSING};
    my $plan = $self->{+PLAN};

    return $pass if $self->{+ENDED};
    return $pass unless $plan;
    return $pass unless $plan->max;
    return $pass if $plan->directive && $plan->directive eq 'NO PLAN';
    return $pass unless $self->{+COUNT} > $plan->max;

    return $self->{+_PASSING} = 0;
}

sub bump {
    my $self = shift;
    my ($pass) = @_;

    $self->{+COUNT}++;
    return if $pass;

    $self->{+FAILED}++;
    $self->{+_PASSING} = 0;
}

sub push_legacy {
    my $self = shift;
    $self->{+LEGACY} ||= [];
    push @{$self->{+LEGACY}} => @_;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::State - Representation of the state of the testing

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

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

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
