package Test::Stream::Event;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test::Stream::Carp qw/confess/;

use Test::Stream::ArrayBase(
    accessors => [qw/context created in_subtest/],
    no_import => 1,
);

sub import {
    my $class = shift;

    # Import should only when event is imported, subclasses do not use this
    # import.
    return if $class ne __PACKAGE__;

    my $caller = caller;
    my (%args) = @_;

    my $ctx_meth = delete $args{ctx_method};

    # %args may override base
    Test::Stream::ArrayBase->apply_to($caller, base => $class, %args);
    require Test::Stream::Context;
    Test::Stream::Context->register_event($caller, $ctx_meth);
}

sub init {
    confess("No context provided!") unless $_[0]->[CONTEXT];
}

sub encoding { $_[0]->[CONTEXT]->encoding }

sub type {
    my $self = shift;
    my $class = blessed($self);
    my $type = $class;
    $type =~ s/^.*:://g;
    return lc($type);
}

1;

__END__

=head1 NAME

Test::Stream::Event - Base class for events

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test::Stream>.

=head1 METHODS

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
