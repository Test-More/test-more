package Test2::AsyncSubtest;
use strict;
use warnings;

our $VERSION = '0.000001';

use Carp qw/croak/;
use Test2::Util qw/get_tid/;

use Test2::API();
use Test2::Hub::AsyncSubtest();
use Test2::Util::Trace();
use Test2::Event::Exception();

use Test2::Util::HashBase qw/name hub errored events _finished event_used pid tid/;

our @CARP_NOT = qw/Test2::Tools::AsyncSubtest/;

sub init {
    my $self = shift;

    croak "'name' is a required attribute"
        unless $self->{+NAME};

    $self->{+PID} = $$;
    $self->{+TID} = get_tid();

    unless($self->{+HUB}) {
        my $ipc = Test2::API::test2_ipc();
        my $hub = Test2::Hub::AsyncSubtest->new(format => undef, ipc => $ipc);
        $self->{+HUB} = $hub;
    }

    my $hub = $self->{+HUB};
    my @events;
    $hub->listen(sub { push @events => $_[1] });
    $self->{+EVENTS} = \@events;
}

sub run {
    my $self = shift;
    my $code = pop;
    my %params = @_;

    croak "AsyncSubtest->run() takes a codeblock as its last argument"
        unless $code && ref($code) eq 'CODE';

    croak "Subtest is already complete, cannot call run()"
        if $self->{+_FINISHED};

    my $hub = $self->{+HUB};
    my $stack = Test2::API::test2_stack();
    $stack->push($hub);
    my ($ok, $err, $finished);
    T2_SUBTEST_WRAPPER: {
        $ok = eval { $code->($params{args} ? @{$params{args}} : ()); 1 };
        $err = $@;

        # They might have done 'BEGIN { skip_all => "whatever" }'
        if (!$ok && $err =~ m/Label not found for "last T2_SUBTEST_WRAPPER"/) {
            $ok  = undef;
            $err = undef;
        }
        else {
            $finished = 1;
        }
    }
    $stack->pop($hub);

    if (!$finished) {
        if(my $bailed = $hub->bailed_out) {
            my $ctx = Test2::API::context();
            $ctx->bail($bailed->reason);
            $ctx->release;
        }
        my $code = $hub->exit_code;
        $ok = !$code;
        $err = "Subtest ended with exit code $code" if $code;
    }

    unless($ok) {
        my $e = Test2::Event::Exception->new(
            error => $err,
            trace => $params{trace} || Test2::Util::Trace->new(
                frame => [caller(0)],
            ),
        );
        $hub->send($e);
        $self->{+ERRORED} = 1;
    }

    return $hub->is_passing;
}

sub finish {
    my $self = shift;
    my %params = @_;

    croak "Subtest is already finished"
        if $self->{+_FINISHED}++;

    croak "Subtest can only be finished in the process that created it"
        unless $$ == $self->{+PID};

    croak "Subtest can only be finished in the thread that created it"
        unless get_tid == $self->{+TID};

    my $hub = $self->{+HUB};
    my $trace = $params{trace} ||= Test2::Util::Trace->new(
        frame => [caller[0]],
    );

    $hub->finalize($trace, 1)
        unless $hub->no_ending || $hub->ended;

    if ($hub->ipc) {
        $hub->ipc->drop_hub($hub->hid);
        $hub->set_ipc(undef);
    }

    return $hub->is_passing;
}

sub event_data {
    my $self = shift;
    my $hub = $self->{+HUB};

    croak "Subtest data can only be used in the process that created it"
        unless $$ == $self->{+PID};

    croak "Subtest data can only be used in the thread that created it"
        unless get_tid == $self->{+TID};

    $self->{+EVENT_USED} = 1;

    return (
        pass => $hub->is_passing,
        name => $self->{+NAME},
        buffered  => 1,
        subevents => $self->{+EVENTS},
    );
}

sub diagnostics {
    my $self = shift;
    # If the subtest died then we've already sent an appropriate event. No
    # need to send another telling the user that the plan was wrong.
    return if $self->{+ERRORED};

    croak "Subtest diagnostics can only be used in the process that created it"
        unless $$ == $self->{+PID};

    croak "Subtest diagnostics can only be used in the thread that created it"
        unless get_tid == $self->{+TID};

    my $hub = $self->{+HUB};
    return if $hub->check_plan;
    return "Bad subtest plan, expected " . $hub->plan . " but ran " . $hub->count;
}

sub DESTROY {
    my $self = shift;
    return if $self->{+EVENT_USED};
    return if $self->{+PID} != $$;
    return if $self->{+TID} != get_tid;

    warn "Subtest $self->{+NAME} did not finish!" unless $self->{+_FINISHED};
    warn "Subtest $self->{+NAME} was not used to procude any events";

    exit 255;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::AsyncSubtest - Object representing an async subtest.

=head1 DESCRIPTION

Regular subtests have a limited scope, they start, events are generated, then
they close and send an L<Test2::Event::Subtest> event. This is a problem if you
want the subtest to keep recieving events while other events are also being
generated. This class implements subtests that stay pen until you decide to
close them.

This is mainly useful for tools that start a subtest in one process or thread
and then spawn children. In many cases it is nice to let the parent process
continue instead of waiting on the children.

=head1 SYNOPSYS

B<Note:> Most people should use L<Test2::Tools::AsyncSubtest> instead of
directly interfacing with this package.

    use Test2::AsyncSubtest;

    my $ast = Test2::AsyncSubtest->new(name => 'a subtest');

    ok(1, "event outside of subtest");

    $ast->run(sub { ok(1, 'event in subtest') }

    ok(1, "another event outside of subtest");

    $ast->run(sub { ok(1, 'another event in subtest') }

    ...

    my $bool = $ast->finish;

    $ctx->send_event(
        'Subtest',
        $ast->event_data,
    );

    $ctx->diag($_) for $ast->diagnostics;

=head1 CONSTRUCTION

    my $ast = Test2::AsyncSubtest->new(
        name => 'a subtest',
        hub  => undef,
    );

=over 4

=item name => $name (required)

Specify the subtest name. This argument is required.

=item hub => $hub (optional)

Specify a hub to use. This is almost never necessary, typically you let the
constructor create a hub for you.

If you do provide your own hub it should be an instance of
L<Test2::Hub::AsyncSubtest>.

=back

=head1 METHODS

=over 4

=item $passing = $ast->run(sub { ... })

=item $passing = $ast->run(%params, sub { ... })

Run will run the provided codeblock with the subtest hub at the top of the
stack. The hub will be removed from the stack when the codeblock returns.

The codelbock must be the very last argument to the sub. All other arguments
will be used as an C<%params> hash.

Params may be C<< args => [...] >>, which will be passed into the codeblock as
argments. Or they may be C<< trace => Test2::Util::Trace->new(...) >> to
provide a trace for any events generated.

=item $passing = $ast->finish()

=item $passing = $ast->finish(trace => $trace)

This will complete the subtest. Optinally you may provide C<< trace => $trace
>> which must be an instance of L<Test2::Util::Trace>.

=item %event_data = $ast->event_data()

Get the data that should be used in a call to
C<< $ctx->send_event(Subtest, %event_data) >> for the final
L<Test2::Event::Subtest> event.

=item @diags = $ast->diagnostics()

Get the extra diagnostics that should be displayed at the end of the subtest.

=back

=head1 SOURCE

The source code repository for Test2-AsyncSubtest can be found at
F<http://github.com/Test-More/Test2-AsyncSubtest/>.

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

See F<http://dev.perl.org/licenses/>

=cut
