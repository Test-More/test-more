package Test::Stream::Event::Plan;
use strict;
use warnings;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event(
    accessors => [qw/max directive reason/],
);

use Test::Stream::Carp qw/confess/;

my %ALLOWED = (
    'SKIP'    => 1,
    'NO PLAN' => 1,
);

sub init {
    if ($_[0]->[DIRECTIVE]) {
        $_[0]->[DIRECTIVE] = 'SKIP'    if $_[0]->[DIRECTIVE] eq 'skip_all';
        $_[0]->[DIRECTIVE] = 'NO PLAN' if $_[0]->[DIRECTIVE] eq 'no_plan';

        confess "'" . $_[0]->[DIRECTIVE] . "' is not a valid plan directive"
            unless $ALLOWED{$_[0]->[DIRECTIVE]};
    }
    else {
        $_[0]->[DIRECTIVE] = '';
        confess "Cannot have a reason without a directive!"
            if defined $_[0]->[REASON];

        confess "No number of tests specified"
            unless defined $_[0]->[MAX];


    }
}

sub to_tap {
    my $self = shift;

    my $max       = $self->[MAX];
    my $directive = $self->[DIRECTIVE];
    my $reason    = $self->[REASON];

    return if $directive && $directive eq 'NO PLAN';

    my $plan = "1..$max";
    if ($directive) {
        $plan .= " # $directive";
        $plan .= " $reason" if defined $reason;
    }

    return [OUT_STD, "$plan\n"];
}

1;

__END__

=head1 NAME

Test::Stream::Event::Plan - The event of a plan

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
