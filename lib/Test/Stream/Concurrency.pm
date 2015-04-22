package Test::Stream::Concurrency;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test::Stream::Util qw/try/;

use Carp qw/confess/;

sub spawn {
    for my $mod (@_) {
        # This is a method that can be called on us or subclasses.
        next if $mod eq __PACKAGE__;
        my $file = $mod;
        $file =~ s{::}{/}g;
        $file .= ".pm";
        my ($ok, $err) = try { require $file };
        next unless $ok;
        next unless $mod->is_viable();
        my $instance = $mod->new() || next;
        return $instance;
    }

    return undef;
}

for my $meth (qw/is_viable new send cull/) {
    no strict 'refs';
    *$meth = sub {
        my $thing = shift;
        my $class = blessed($thing) || $thing;
        confess "'$class' did not define the required method '$meth'."
    };
}

sub cleanup { };

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Concurrency - Base class for concurrency models in Test::Stream

=head1 SYNOPSIS

=head2 SPECIFYING MODELS

    use Test::Stream concurrency => ['My::Concurrency::Model', 'My::Concurrency::Fallback', ...];

=head2 WRITING MODELS

    package My::Concurrency::Model;
    use strict;
    use warnings;

    use base 'Test::Stream::Concurrency';

    # Checks to verify this model works in the current environment
    sub is_viable {
        return 1 unless $^O ne 'SUPPORTED_PLATFORM';
        return 1 unless $ENV{NO_MODEL};
        return 0;
    }

    # Creates a new instance
    sub new { ... }

    sub send {
        my $self = shift;
        my %params = @_;

        # arrayrefs with process-id and thread-id
        my $dest = $params{dest}; # where to send the events
        my $orig = $params{orig}; # usually current proc-id and thread-id

        # arrayref of events to send
        my $events = $param{events};

        ... # Here is where you send the events to the other thread/proc
    }

    sub cull {
        my $self = shift;

        # This tells us the pid and thread id we think we are, only cull
        # results intended for this combination.
        my ($pid, $tid) = @_; # proc-id and thread-id

        my @events = ...; # Here is where you get the events

        return @events;
    }

    sub cleanup {
        my $self = shift;
        my ($pid, $tid) = @_;

        ... # any code you need to run AFTER all tests are complete. This is
        ... # called by the hub's destructor.
    }

    1;

=head1 CLASS METHODS

=head1 METHODS SUBCLASSES ARE EXPECTED TO HAVE

=head2 SUBCLASSES MUST IMPLEMENT

=over 4

=item $class->is_viable()

This must be a class method. This method should return true if the concurrency
model is expected to work in the current environment. If the concurrency model
is not viable in the current environment it should return 0.

    sub is_viable {
        return 1 unless $^O ne 'SUPPORTED_PLATFORM';
        return 1 unless $ENV{NO_MODEL};
        return 0;
    }

=item $sync = $class->new()

Create a new instance of the concurrency model. This should not require any
arguments.

=item $sync->send(dest => [$DPID, $DTID], orig => [$$, get_tid()], events => \@events);

Used to send events from the current thread/proc to the destination
thread/proc. The C<dest> argument will always be an arrayref with the proc-id
and thread-id to which the events should be sent. The C<orig> argument will
always have the proc-id and thread-id that the events are from, usually the
current pid and tid. The c<events> argument will always be an arrayref of
events to send.

    sub send {
        my $self = shift;
        my %params = @_;

        # arrayrefs with process-id and thread-id
        my $dest = $params{dest}; # where to send the events
        my $orig = $params{orig}; # usually current proc-id and thread-id

        # arrayref of events to send
        my $events = $param{events};

        ... # Here is where you send the events to the other thread/proc
    }

=item @events = $sync->cull($pid, $tid)

This is used to collect results sent by another process or thread. The argument
are the proc-id and thread-id that should be used to identify what events
belong to us, these correspond to the C<dest> argument of C<< $sync->send() >>.
These will usually be the current proc-id and thread-id, but they may not be if
someone is doing something clever.

    sub cull {
        my $self = shift;

        # This tells us the pid and thread id we think we are, only cull
        # results intended for this combination.
        my ($pid, $tid) = @_; # proc-id and thread-id

        my @events = ...; # Here is where you get the events

        return @events;
    }

=back

=head2 SUBCLASSES MAY IMPLEMENT

=over 4

=item $sync->cleanup($pid, $tid)

Used for any final cleanup tasks. This is called by the L<Test::Stream:Hub>
objects destructor.

    sub cleanup {
        my $self = shift;
        my ($pid, $tid) = @_;

        ... # any code you need to run AFTER all tests are complete. This is
        ... # called by the hub's destructor.
    }

=back

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
