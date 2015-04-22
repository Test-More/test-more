package Test::Stream::Concurrency;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test::Stream::Util qw/try/;
use Test::Stream::Threads;

use Carp qw/confess/;

use Test::Stream::HashBase(
    accessors => [qw/wait join/],
);

sub before_import {
    my $class = shift;
    my ($importer, $list) = @_;

    require Test::Stream;
    my $hub = Test::Stream->shared;

    my @args;
    my %args;
    my @new_list;
    while (@$list) {
        my $arg = shift @$list;
        if ($arg =~ m/^(driver|fallback)$/) {
            push @args => ($arg, shift @$list);
        }
        if ($arg =~ m/^(wait|join)$/) {
            $args{$arg} = shift @$list;
        }
        else {
            push @new_list => $arg;
        }
    }
    @$list = @new_list;

    $args{wait} = 1 unless exists $args{wait};
    $args{join} = 1 unless exists $args{join};

    if (my $driver = $hub->concurrency_driver) {
        $driver->set_join($args{join}) unless defined $driver->join;
        $driver->set_wait($args{wait}) unless defined $driver->wait;
    }
    else {
        $hub->set_concurrency_driver($class->spawn(@args, %args));
    }
}

sub spawn {
    my $class = shift;

    my $driver = $class eq __PACKAGE__ ? $ENV{TS_CONCURRENCY_DRIVER} || 'Test::Stream::Concurrency::Files' : $class;
    my @fallback;
    my %config = (wait => 1, join => 1);

    while (@_) {
        my $key = shift;
        my $val = shift;
        if ($key eq 'driver') {
            $driver = $val;
        }
        elsif ($key eq 'fallback') {
            push @fallback => $val;
        }
        else {
            $config{$key} = $val;
        }
    }

    push @fallback => 'Test::Stream::Concurrency::Files'
        unless @fallback;

    unshift @fallback => $driver;

    my $instance;
    for my $mod (@fallback) {
        # This is a method that can be called on us or subclasses.
        next if $mod eq __PACKAGE__;
        my $file = $mod;
        $file =~ s{::}{/}g;
        $file .= ".pm";
        my ($ok, $err) = try { require $file };
        next unless $ok;
        next unless $mod->is_viable();
        $instance = $mod->new();
        last if $instance;
    }

    return undef unless $instance;

    $instance->configure(%config);
    return $instance;
}

sub configure {
    my $self = shift;

    if (@_) {
        my %args = @_;
        for my $k (JOIN, WAIT) {
            next unless defined $args{$k};

            confess "$k is already set to $self->{$k}, cannot set it to $args{$k}"
                if defined $self->{$k}
                && $self->{$k} != $args{$k};

            $self->{$k} = $args{$k};
        }
    }

    return (wait => $self->{+WAIT}, join => $self->{+JOIN});
}

sub finalize {
    my $self = shift;

    while ($self->wait) {
        last if -1 == CORE::wait();
    }
    if (USE_THREADS && $self->join) {
        $_->join for threads->list();
    }
}

for my $meth (qw/is_viable send cull/) {
    no strict 'refs';
    *$meth = sub {
        my $thing = shift;
        my $class = blessed($thing) || $thing;
        confess "'$class' did not define the required method '$meth'."
    };
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Concurrency - Enable concurrency in Test::Stream.

=head1 SYNOPSIS

This *just works* for nearly all cases and environments:

    use Test::Stream::Concurrency;

    ...

By default this loads the L<Test::Stream::Concurrency::Files> driver. The
default may change at any time in the future, so if you care what driver is
used then you must specify it.

=head2 JOIN AND WAIT

Join and wait are turned on by default:

    use Test::Stream::Concurrency;

is the same as

    use Test::Stream::Concurrency join => 1, wait => 1;

You can also request they be disabled:

    use Test::Stream::Concurrency join => 0, wait => 0;

If you do not want to enable them, but do want to allow something else to
enable them, you can set them to undef. This is how Legacy support works:

    use Test::Stream::Concurrency join => undef, wait => undef;

=head2 SPECIFYING DRIVERS

    use Test::Stream::Concurrency(
        driver   => 'My::Concurrency::Driver',
        fallback => 'My::Concurrency::Fallback',
        fallback => 'My::Concurrency::Fallback2',
    );

You can also specify a default driver via the C<$TS_CONCURRENCY_DRIVER>
environment variable:

    $ TS_CONCURRENCY_DRIVER='My::Concurrency::Driver' prove my_test.t

The environment variable value is ignored if a driver is specified in code.

Directly using a driver will attempt to load it as the driver. That is to say
that these 2 use statements are identical:

    use Test::Stream::Concurrency driver => 'My::Concurrency::Driver';
    use My::Concurrency::Driver;

=head1 DEFINED CONCURRENCY BEHAVIOR

How some test tools should act under concurrency is not always clear. This
section outlines some edge cases, and how they are handled by
Test::Stream::Concurrency.

=head2 WAIT, JOIN, and BACKCOMPAT

By Default Test::Stream::Concurrency loads with C<wait> and C<join> enabled.
These behaviors will cause the parent process to wait for all child process or
threads before exiting. This behavior is helpful and prevents you from making
common mistakes.

Legacy thread support and Test::SharedFork did not provide either of these
behaviors, so in purely backwords compatible mode they are not loaded. This
happens when concurrency is enabled automatically because C<threads> are
loaded, or when you load Test::SharedFork. Loading L<Test::Stream::Concurrency>
at any point will turn these features on unless you ask to turn them off.

=head2 ENDING THE PARENT PROCESS

=head3 PARENT ENDS BEFORE CHILD PROCESS

If this happens, and C<wait> is not set, the child process will provide a
helpful warning, and send a 'not ok' to stdout in hopes the harness will notice
it and record a test failure. It is possible a harness could miss this
resulting in a false-pass. This is the primary reason for the C<wait> option,
and why it is on by default.

=head3 PARENT ENDS BEFORE CHILD THREAD

If this happens, and C<join> is not set, perl simply ends the child thread and
prints a message telling you it was running. There is no way for the child
thread to alert the harness that something went wrong. This usually results in
a false-pass. This is the primary reason for the C<join> option, and why it is
on by default.

=head2 SUBTESTS

=head3 STARTING A CHILD BEFORE A SUBTEST

This simply did not work in legacy code. It now works as expected, the subtest
runs in the child process, the result is sent to the parent. In Legacy code
this would fail because test numbers and plans would be wrong.

=head3 STARTING A CHILD INSIDE A SUBTEST

In legacy code this worked fine so long as you waited or joined before the
subtest ended, failing to wait or join could result in false-passes.

With Test::Stream this just works as expected. You still need to wait or join
before the parent process finishes the subtest. If you fail to wait/join you
will get a helpful error message and a test failure.

=head2 DEMOS

This dist comes with a set of demonstration scripts in C<./concurrency_demos/>.
These scripts demonstrate most of the edge cases, and how they are handled in
modern or legacy Test-Simple dists. The output of each script can be found
under the __END__ section inside each script.

=head1 INSTANCE METHODS

=over

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

=item $bool = $sync->wait;

This is true if Test::Stream should wait on all child processes before exiting.
This can be modified using the C<< $sync->configure >> method.

=item $bool = $sync->join;

This is true if Test::Stream should join on all child threads before exiting.
This can be modified using the C<< $sync->configure >> method.

=item %config = $sync->configure()

=item $sync->configure(wait => $wbool, join => $jbool)

Used to get/set the configuration. Currently the configuration contains 2 keys:
C<join> and C<wait>.

=item $sync->finalize

Called by Test::Stream at the end of testing, it is used to wait on child
processed and join child threads.

=back

=head1 WRITING DRIVERS

    package My::Concurrency::Driver;
    use strict;
    use warnings;

    use base 'Test::Stream::Concurrency';

    # Checks to verify this driver works in the current environment
    sub is_viable {
        return 1 unless $^O ne 'SUPPORTED_PLATFORM';
        return 1 unless $ENV{NO_DRIVER};
        return 0;
    }

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

    1;

=head2 METHODS SUBCLASSES MUST IMPLEMENT

=over 4

=item $class->is_viable()

This must be a class method. This method should return true if the concurrency
driver is expected to work in the current environment. If the concurrency driver
is not viable in the current environment it should return 0.

    sub is_viable {
        return 1 unless $^O ne 'SUPPORTED_PLATFORM';
        return 1 unless $ENV{NO_DRIVER};
        return 0;
    }

=item $sync = $class->new()

Create a new instance of the concurrency driver. This should not require any
arguments.

There is a C<new()> method in the base class, no need to roll your own unless
you are doing something special.

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
