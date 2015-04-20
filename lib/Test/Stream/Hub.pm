package Test::Stream::Hub;
use strict;
use warnings;

use Test::Stream::Context qw/context/;
use Test::Stream::Threads;
use Test::Stream::IOSets;
use Test::Stream::Util qw/try/;
use Test::Stream::Carp qw/croak confess carp cluck/;
use Test::Stream::State qw/PLAN COUNT FAILED ENDED LEGACY/;

use Test::Stream::HashBase(
    accessors => [qw{
        no_ending no_diag no_header
        pid tid
        states
        subtests
        subtest_tap_instant
        subtest_tap_delayed
        mungers
        listeners
        follow_ups
        bailed_out
        exit_on_disruption
        use_tap use_legacy _use_fork
        use_numbers
        io_sets
        event_id
        in_subthread
    }],
);

my $SEND_LITE = 1;

sub init {
    my $self = shift;

    $self->{+PID} = $$;
    $self->{+TID} = get_tid();

    $self->{+USE_TAP}     = 1;
    $self->{+USE_NUMBERS} = 1;
    $self->{+EVENT_ID}    = 1;
    $self->{+NO_ENDING}   = 1;

    $self->{+STATES}  = [Test::Stream::State->new];
    $self->{+IO_SETS} = Test::Stream::IOSets->new;

    $self->{+SUBTESTS} = [];

    $self->{+SUBTEST_TAP_INSTANT} = 1;
    $self->{+SUBTEST_TAP_DELAYED} = 0;

    $self->use_fork if USE_THREADS;

    $self->{+EXIT_ON_DISRUPTION} = 1;
}

# Shortcuts to the current state attributes
sub state  { $_[0]->{+STATES}->[-1]            }
sub plan   { $_[0]->{+STATES}->[-1]->{+PLAN}   }
sub count  { $_[0]->{+STATES}->[-1]->{+COUNT}  }
sub failed { $_[0]->{+STATES}->[-1]->{+FAILED} }
sub ended  { $_[0]->{+STATES}->[-1]->{+ENDED}  }
sub legacy { $_[0]->{+STATES}->[-1]->{+LEGACY} }

sub is_passing {
    my $self = shift;
    my $state = $self->{+STATES}->[-1];
    return $state->is_passing(@_);
}

sub listen {
    my $self = shift;
    for my $sub (@_) {
        next unless $sub;

        croak "listen only takes coderefs for arguments, got '$sub'"
            unless ref $sub && ref $sub eq 'CODE';

        push @{$self->{+LISTENERS}} => $sub;
    }

    if ($SEND_LITE) {
        no warnings 'redefine';
        *send = \&_send_heavy;
        $SEND_LITE = 0;
    }
}

sub unlisten {
    my $self = shift;
    my %subs = map {$_ => $_} @_;
    ${$self->{+LISTENERS}} = grep { !$subs{$_} == $_ } @{$self->{+LISTENERS}};
}

sub munge {
    my $self = shift;
    for my $sub (@_) {
        next unless $sub;

        croak "munge only takes coderefs for arguments, got '$sub'"
            unless ref $sub && ref $sub eq 'CODE';

        push @{$self->{+MUNGERS}} => $sub;
    }

    if ($SEND_LITE) {
        no warnings 'redefine';
        *send = \&_send_heavy;
        $SEND_LITE = 0;
    }
}

sub unmunge {
    my $self = shift;
    my %subs = map {$_ => $_} @_;
    ${$self->{+MUNGERS}} = grep { !$subs{$_} == $_ } @{$self->{+MUNGERS}};
}

sub follow_up {
    my $self = shift;
    for my $sub (@_) {
        next unless $sub;

        croak "follow_up only takes coderefs for arguments, got '$sub'"
            unless ref $sub && ref $sub eq 'CODE';

        push @{$self->{+FOLLOW_UPS}} => $sub;
    }
}

sub use_fork {
    return 1 if $_[0]->{+_USE_FORK};
    require File::Temp;
    require Storable;

    $_[0]->{+_USE_FORK} ||= File::Temp::tempdir(CLEANUP => 0);

    confess "Could not get a temp dir" unless $_[0]->{+_USE_FORK};
    if ($^O eq 'VMS') {
        require VMS::Filespec;
        $_[0]->{+_USE_FORK} = VMS::Filespec::unixify($_[0]->{+_USE_FORK});
    }

    if ($SEND_LITE) {
        no warnings 'redefine';
        *send = \&_send_heavy;
        $SEND_LITE = 0;
    }

    return 1;
}

sub fork_out {
    my $self = shift;

    my $tempdir = $self->{+_USE_FORK};
    confess "Fork support has not been turned on!" unless $tempdir;

    my $orig = "$$-" . get_tid();
    my $dest;
    if (my $subtest = $self->{+SUBTESTS}->[-1]) {
        $dest = $subtest->{pid} . '-' . $subtest->{tid};
    }
    else {
        $dest = $self->{+PID} . '-' . $self->{+TID};
    }
    my $route = "$dest-$orig";

    for my $event (@_) {
        next unless $event;
        next if $event->isa('Test::Stream::Event::Finish');

        # First write the file, then rename it so that it is not read before it is ready.
        my $name =  $tempdir . "/$route-" . ($self->{+EVENT_ID}++);
        my ($ret, $err) = try { Storable::store($event, $name) };
        # Temporary to debug an error on one cpan-testers box
        unless ($ret) {
            require Data::Dumper;
            confess(Data::Dumper::Dumper({ error => $err, event => $event}));
        }
        rename($name, "$name.ready") || confess "Could not rename file '$name' -> '$name.ready'";
    }
}

sub fork_cull {
    my $self = shift;

    my $tempdir = $self->{+_USE_FORK} || return;

    opendir(my $dh, $tempdir) || croak "could not open temp dir ($tempdir)!";

    my $get = "$$-" . get_tid();

    my @files = sort readdir($dh);
    for my $file (@files) {
        next if $file =~ m/^\.+$/;
        next unless $file =~ m/^\Q$get\E-\d+-\d+-\d+\.ready$/;

        # Untaint the path.
        my $full = "$tempdir/$file";
        ($full) = ($full =~ m/^(.*)$/gs);

        my $obj = Storable::retrieve($full);
        confess "Empty event object found '$full'" unless $obj;

        if ($ENV{TEST_KEEP_TMP_DIR}) {
            rename($full, "$full.complete")
                || confess "Could not rename file '$full', '$full.complete'";
        }
        else {
            unlink($full) || die "Could not unlink file: $file";
        }

        $self->send($obj);
    }

    closedir($dh);
}

sub done_testing {
    my $self = shift;
    my ($ctx, $num) = @_;
    my $state = $self->{+STATES}->[-1];

    if (my $old = $state->ended) {
        my ($p1, $f1, $l1) = $old->call;
        $ctx->ok(0, "done_testing() was already called at $f1 line $l1");
        return;
    }

    # Do not run followups in subtest!
    if ($self->{+FOLLOW_UPS} && !@{$self->{+SUBTESTS}}) {
        $_->($ctx) for @{$self->{+FOLLOW_UPS}};
    }

    $state->set_ended($ctx->snapshot);

    my $ran  = $state->count;
    my $plan = $state->plan;
    my $pmax = $plan ? $plan->max : 0;

    if (defined($num) && $pmax && $num != $pmax) {
        $ctx->ok(0, "planned to run $pmax but done_testing() expects $num");
        return;
    }

    unless ($plan) {
        # bypass Test::Builder::plan() monkeypatching
        my $e = $ctx->build_event('Plan', max => $num || $pmax || $ran);
        $ctx->send($e);
    }

    if ($pmax && $pmax != $ran) {
        $state->is_passing(0);
        return;
    }

    if ($num && $num != $ran) {
        $state->is_passing(0);
        return;
    }

    unless ($ran) {
        $state->is_passing(0);
        return;
    }
}

my $SUBTEST_ID = 1;
sub subtest_start {
    my $self = shift;
    my ($name, %params) = @_;

    if ($SEND_LITE) {
        no warnings 'redefine';
        *send = \&_send_heavy;
        $SEND_LITE = 0;
    }

    my $state = Test::Stream::State->new;

    $params{parent_todo} ||= context()->in_todo;

    if(@{$self->{+SUBTESTS}}) {
        $params{parent_todo} ||= $self->{+SUBTESTS}->[-1]->{parent_todo};
    }

    my $tid = get_tid();

    push @{$self->{+STATES}}    => $state;
    push @{$self->{+SUBTESTS}} => {
        instant => $self->{+SUBTEST_TAP_INSTANT},
        delayed => $self->{+SUBTEST_TAP_DELAYED},

        %params,

        state  => $state,
        events => [],
        name   => $name,
        pid    => $$,
        tid    => $tid,
        id     => "$$-$tid-" . $SUBTEST_ID++,
    };

    return $self->{+SUBTESTS}->[-1];
}

sub subtest_stop {
    my $self = shift;
    my ($name) = @_;

    confess "No subtest to stop!"
        unless @{$self->{+SUBTESTS}};

    confess "Subtest name mismatch!"
        unless $self->{+SUBTESTS}->[-1]->{name} eq $name;

    my $st = pop @{$self->{+SUBTESTS}};
    pop @{$self->{+STATES}};

    unless ($st->{pid} == $$ && $st->{tid} == get_tid()) {
        cluck "Subtest '$st->{name}' ended in a different process or thread from when it started.\n"
            . "You must exit any child processes or threads created in a subtest BEFORE it ends.";

        exit 255;
    }

    return $st;
}

sub subtest { @{$_[0]->{+SUBTESTS}} ? $_[0]->{+SUBTESTS}->[-1] : () }

{
    no warnings 'once';
    *send = \&_send_lite;
}
sub _send_lite {
    my ($self, $e) = @_;
    my $cache = $self->_preprocess_event($self->{+STATES}->[-1], $e);
    $self->_render_tap($cache) unless $cache->{no_out};

    if ($cache->{is_plan}) {
        $cache->{state}->set_plan($e);
        if ($e->directive && $e->directive eq 'SKIP') {
            die $e unless $self->{+EXIT_ON_DISRUPTION};
            exit 0;
        }
    }
    elsif (!$cache->{do_tap} && $e->isa('Test::Stream::Event::Bail')) {
        $self->{+BAILED_OUT} = $e;
        $self->{+NO_ENDING}  = 1;
        die $e unless $self->{+EXIT_ON_DISRUPTION};
        exit 255;
    }

    return $e;
}

sub _send_heavy {
    my ($self, $e) = @_;

    my $cache = $self->_preprocess_event($self->{+STATES}->[-1], $e);

    # Subtests get dibbs on events
    my $num;
    if($num = $e->{in_subtest}) {
        my $sid = $e->in_subtest_id();
        $num -= 1;
        my $st = $self->{+SUBTESTS}->[$num];

        confess "Attempt to send event ($e) to ended subtest ($sid)"
            unless $st && $st->{id} eq "$sid";

        $e->context->set_diag_todo(1) if $st->{parent_todo};
        push @{$st->{events}} => $e;
        $self->_render_tap($cache) if $st->{instant} && !$cache->{no_out};
    }
    elsif ($num = @{$self->{+SUBTESTS}}) {
        my $st = $self->{+SUBTESTS}->[-1];

        $e->set_in_subtest($num);
        $e->set_in_subtest_id($st->{id});

        if ($self->{+_USE_FORK} && ($$ != $st->{pid} || get_tid() != $st->{tid})) {
            $self->fork_out($e);
        }
        else {
            $e->context->set_diag_todo(1) if $st->{parent_todo};
            push @{$st->{events}} => $e;
            $self->_render_tap($cache) if $st->{instant} && !$cache->{no_out};
        }
    }
    elsif ($self->{+_USE_FORK} && ($$ != $self->{+PID} || get_tid() != $self->{+TID})) {
        $self->fork_out($e);
    }
    else {
        $self->_process_event($e, $cache);
    }

    $self->_postprocess_event($e, $cache);

    return $e;
}

sub _preprocess_event {
    my ($self, $state, $e) = @_;
    my $cache = {tap_event => $e, state => $state};

    if ($e->isa('Test::Stream::Event::Ok')) {
        $state->bump($e->effective_pass);
        $cache->{do_tap} = 1;
    }
    elsif (!$self->{+NO_HEADER} && $e->isa('Test::Stream::Event::Finish')) {
        $state->set_ended($e->context->snapshot);

        my $plan = $state->plan;
        if ($plan && $e->tests_run && $plan->directive eq 'NO PLAN') {
            $plan->set_max($state->count);
            $plan->set_directive(undef);
            $cache->{tap_event} = $plan;
            $cache->{do_tap} = 1;
        }
        else {
            $cache->{do_tap} = 0;
            $cache->{no_out} = 1;
        }
    }
    elsif ($self->{+NO_DIAG} && $e->isa('Test::Stream::Event::Diag')) {
        $cache->{no_out} = 1;
    }
    elsif ($e->isa('Test::Stream::Event::Plan')) {
        $cache->{is_plan} = 1;

        if($self->{+NO_HEADER}) {
            $cache->{no_out} = 1;
        }
        elsif(my $existing = $state->plan) {
            my $directive = $existing->directive;

            if (!$directive || $directive eq 'NO PLAN') {
                my ($p1, $f1, $l1) = $existing->context->call;
                my ($p2, $f2, $l2) = $e->context->call;
                die "Tried to plan twice!\n    $f1 line $l1\n    $f2 line $l2\n";
            }
        }

        my $directive = $e->directive;
        $cache->{no_out} = 1 if $directive && $directive eq 'NO PLAN';
    }

    $state->push_legacy($e) if $self->{+USE_LEGACY};

    $cache->{number} = $state->count;

    return $cache;
}

sub _process_event {
    my ($self, $e, $cache) = @_;

    if ($self->{+MUNGERS}) {
        $_->($self, $e, $e->subevents) for @{$self->{+MUNGERS}};
    }

    $self->_render_tap($cache) unless $cache->{no_out};

    if ($self->{+LISTENERS}) {
        $_->($self, $e) for @{$self->{+LISTENERS}};
    }
}

sub _postprocess_event {
    my ($self, $e, $cache) = @_;

    if ($cache->{is_plan}) {
        $cache->{state}->set_plan($e);
        return unless $e->directive;
        return unless $e->directive eq 'SKIP';

        if (my $subtest = @{$self->{+SUBTESTS}}) {
            $self->{+SUBTESTS}->[-1]->{early_return} = $e;
            my $begin = _scan_for_begin('Test::Stream::Subtest::subtest');

            if ($begin) {
                warn "SKIP_ALL in subtest via 'BEGIN' or 'use', using exception for flow control\n";
                die $e;
            }
            elsif(defined $begin) {
                no warnings 'exiting';
                eval { last TEST_HUB_SUBTEST };
                warn "SKIP_ALL in subtest flow control error: $@";
                warn "Falling back to using an exception.\n";
                die $e;
            }
            else {
                warn "SKIP_ALL in subtest could not find flow-control label, using exception for flow control\n";
                die $e;
            }
        }

        die $e unless $self->{+EXIT_ON_DISRUPTION};
        exit 0;
    }
    elsif (!$cache->{do_tap} && $e->isa('Test::Stream::Event::Bail')) {
        $self->{+BAILED_OUT} = $e;
        $self->{+NO_ENDING}  = 1;

        if (my $subtest = @{$self->{+SUBTESTS}}) {
            $self->{+SUBTESTS}->[-1]->{early_return} = $e;
            my $begin = _scan_for_begin('Test::Stream::Subtest::subtest');

            if ($begin) {
                warn "BAILOUT in subtest via 'BEGIN' or 'use', using exception for flow control.\n";
                die $e;
            }
            elsif(defined $begin) {
                no warnings 'exiting';
                eval { last TEST_HUB_SUBTEST };
                warn "BAILOUT in subtest flow control error: $@";
                warn "Falling back to using an exception.\n";
                die $e;
            }
            else {
                warn "BAILOUT in subtest could not find flow-control label, using exception for flow control.\n";
                die $e;
            }
        }

        die $e unless $self->{+EXIT_ON_DISRUPTION};
        exit 255;
    }
}

sub _render_tap {
    my ($self, $cache) = @_;

    return if $^C;
    return unless $self->{+USE_TAP};
    my $e = $cache->{tap_event};
    return unless $cache->{do_tap} || $e->can('to_tap');

    my $num = $self->use_numbers ? $cache->{number} : undef;
    my @sets = $e->to_tap($num);

    my $in_subtest = $e->in_subtest || 0;
    my $indent = '    ' x $in_subtest;

    for my $set (@sets) {
        my ($hid, $msg) = @$set;
        next unless $msg;
        my $enc = $e->encoding || confess "Could not find encoding!";
        my $io = $self->{+IO_SETS}->{$enc}->[$hid] || confess "Could not find IO $hid for $enc";

        local($\, $", $,) = (undef, ' ', '');
        $msg =~ s/^/$indent/mg if $in_subtest;
        print $io $msg;
    }
}

sub _scan_for_begin {
    my ($stop_at) = @_;
    my $level = 2;

    while (my @call = caller($level++)) {
        return 1 if $call[3] =~ m/::BEGIN$/;
        return 0 if $call[3] eq $stop_at;
    }

    return undef;
}

sub _reset {
    my $self = shift;

    $self->{+STATES} = [Test::Stream::State->new];

    return unless $self->pid != $$ || $self->tid != get_tid();

    $self->{+PID} = $$;
    $self->{+TID} = get_tid();
    if (USE_THREADS || $self->{+_USE_FORK}) {
        $self->{+_USE_FORK} = undef;
        $self->use_fork;
    }
}

sub DESTROY {
    my $self = shift;

    return if $self->in_subthread;

    my $dir = $self->{+_USE_FORK} || return;

    return unless defined $self->pid;
    return unless defined $self->tid;

    return unless $$        == $self->pid;
    return unless get_tid() == $self->tid;

    if ($ENV{TEST_KEEP_TMP_DIR}) {
        print STDERR "# Not removing temp dir: $dir\n";
        return;
    }

    opendir(my $dh, $dir) || confess "Could not open temp dir! ($dir)";
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        die "Unculled event! You ran tests in a child process, but never pulled them in!\n"
            if $file !~ m/\.complete$/;
        unlink("$dir/$file") || confess "Could not unlink file: '$dir/$file'";
    }
    closedir($dh);
    rmdir($dir) || warn "Could not remove temp dir ($dir)";
}

sub STORABLE_freeze {
    my ($self, $cloning) = @_;
    return if $cloning;
    return ($self);
}

sub STORABLE_thaw {
    my ($self, $cloning, @vals) = @_;
    return if $cloning;
    return Test::Stream->shared;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Hub - The conduit through which all events flow.

=head1 SYNOPSIS

    use Test::Stream;
    my $hub = Test::Stream->shared;
    $hub->send($event);

or

    use Test::Stream::Hub;
    my $hub = Test::Stream::Hub->new();
    $hub->send($event);

=head2 TOGGLES AND CONTROLS

=over 4

=item $hub->use_fork

Turn on forking support (it cannot be turned off).

=item $hub->set_subtest_tap_instant($bool)

=item $bool = $hub->subtest_tap_instant

Render subtest events as they happen.

=item $hub->set_subtest_tap_delayed($bool)

=item $bool = $hub->subtest_tap_delayed

Render subtest events when printing the result of the subtest

=item $hub->set_exit_on_disruption($bool)

=item $bool = $hub->exit_on_disruption

When true, skip_all and bailout will call exit. When false the bailout and
skip_all events will be thrown as exceptions.

=item $hub->set_use_tap($bool)

=item $bool = $hub->use_tap

Turn TAP rendering on or off.

=item $hub->set_use_legacy($bool)

=item $bool = $hub->use_legacy

Turn legacy result storing on and off.

=item $hub->set_use_numbers($bool)

=item $bool = $hub->use_numbers

Turn test numbers on and off.

=item $stash = $hub->subtest_start($name, %params)

=item $stash = $hub->subtest_stop($name)

These will push/pop new states and subtest stashes.

B<Using these directly is not recommended.> Also see the wrapper methods in
L<Test::Stream::Context>.

=back

=head2 SENDING EVENTS

    $hub->send($event)

The C<send()> method is used to issue an event to the hub. This method will
handle thread/fork sych, mungers, listeners, TAP output, etc.

=head2 ALTERING EVENTS

    $hub->munge(sub {
        my ($hub, $event) = @_;

        ... Modify the event object ...

        # return is ignored.
    });

Mungers can never be removed once added. The return from a munger is ignored.
Any changes you wish to make to the object must be done directly by altering
it in place. The munger is called before the event is rendered as TAP, and
AFTER the event has made any necessary state changes.

=head2 LISTENING FOR EVENTS

    $hub->listen(sub {
        my ($hub, $event) = @_;

        ... do whatever you want with the event ...

        # return is ignored
    });

Listeners can never be removed once added. The return from a listener is
ignored. Changing an event in a listener is not something you should ever do,
though no protections are in place to prevent it (this may change!). The
listeners are called AFTER the event has been rendered as TAP.

=head2 POST-TEST BEHAVIORS

    $hub->follow_up(sub {
        my ($context) = @_;

        ... do whatever you need to ...

        # Return is ignored
    });

follow_up subs are called only once, when the hub recieves a finish event. There are 2 ways a finish event can occur:

=over 4

=item $hub->done_testing

A finish event is generated when you call done_testing. The finish event occurs
before the plan is output.

=item EXIT MAGIC

A finish event is generated when the Test::Stream END block is called, just
before cleanup. This event will not happen if it was already geenerated by a
call to done_testing.

=back

=head2 STATE METHODS

=over

=item $hub->states

Get the states arrayref, which holds all the active state objects.

=item $hub->state

Get the current state. The state is an instance of L<Test::Stream::State> which
represents the state of the test run.

=item $hub->plan

Get the plan event, if a plan has been issued.

=item $hub->count

Get the test count so far.

=item $hub->failed

Get the number of failed tests so far.

=item $hub->ended

Get the context in which the tests ended, if they have ended.

=item $hub->legacy

Used internally to store events for legacy support.

=item $hub->is_passing

Check if the test is passing its plan.

=item $hub->fork_cull

Gather events from other threads/processes.

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
