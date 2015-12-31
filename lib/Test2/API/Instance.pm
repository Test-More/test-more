package Test2::API::Instance;
use strict;
use warnings;

our @CARP_NOT = qw/Test2::API Test2::API::Instance Test2::IPC::Driver Test2::Formatter/;
use Carp qw/confess carp/;
use Scalar::Util qw/reftype/;

use Test2::Util qw/get_tid USE_THREADS CAN_FORK pkg_to_file try/;

use Test2::Util::Trace();
use Test2::API::Stack();

use Test2::Util::HashBase qw{
    pid tid
    no_wait
    finalized loaded
    ipc stack formatter
    contexts

    ipc_polling
    ipc_drivers
    formatters

    exit_callbacks
    post_load_callbacks
    context_init_callbacks
    context_release_callbacks
};

# Wrap around the getters that should call _finalize.
BEGIN {
    for my $finalizer (IPC, FORMATTER) {
        my $orig = __PACKAGE__->can($finalizer);
        my $new  = sub {
            my $self = shift;
            $self->_finalize unless $self->{+FINALIZED};
            $self->$orig;
        };

        no strict 'refs';
        no warnings 'redefine';
        *{$finalizer} = $new;
    }
}

{
    my $INST = __PACKAGE__->new;
    sub _internal_use_only_private_instance() { $INST }
}

sub init { $_[0]->reset }

sub reset {
    my $self = shift;

    $self->{+PID} = $$;
    $self->{+TID} = get_tid();
    $self->{+CONTEXTS}    = {};

    $self->{+IPC_DRIVERS} = [];
    $self->{+IPC_POLLING} = undef;

    $self->{+FORMATTERS} = [];
    $self->{+FORMATTER}  = undef;

    $self->{+FINALIZED} = undef;
    $self->{+IPC}       = undef;

    $self->{+NO_WAIT} = 0;
    $self->{+LOADED}  = 0;

    $self->{+EXIT_CALLBACKS}            = [];
    $self->{+POST_LOAD_CALLBACKS}       = [];
    $self->{+CONTEXT_INIT_CALLBACKS}    = [];
    $self->{+CONTEXT_RELEASE_CALLBACKS} = [];

    $self->{+STACK} = Test2::API::Stack->new;
}

sub _finalize {
    my $self = shift;
    my ($caller) = @_;
    $caller ||= [caller(1)];

    $self->{+FINALIZED} = $caller;

    unless ($self->{+FORMATTER}) {
        my ($formatter, $source);
        if ($ENV{T2_FORMATTER}) {
            $formatter = $ENV{T2_FORMATTER};
            $source    = "set by the 'T2_FORMATTER' environment variable";

            $formatter = "Test2::Formatter::$formatter"
                unless $formatter =~ s/^\+//;
        }
        elsif (@{$self->{+FORMATTERS}}) {
            ($formatter) = @{$self->{+FORMATTERS}};
            $source = "Most recently added";
        }
        else {
            $formatter = 'Test2::Formatter::TAP';
            $source    = 'default formatter';
        }

        unless (ref($formatter) || $formatter->can('write')) {
            my $file = pkg_to_file($formatter);
            my ($ok, $err) = try { require $file };
            unless ($ok) {
                my $line   = "* COULD NOT LOAD FORMATTER '$formatter' ($source) *";
                my $border = '*' x length($line);
                die "\n\n  $border\n  $line\n  $border\n\n$err";
            }
        }

        $self->{+FORMATTER} = $formatter;
    }

    # Turn on IPC if threads are on, drivers are reigstered, or the Test2::IPC
    # module is loaded.
    return unless USE_THREADS || $INC{'Test2/IPC.pm'} || @{$self->{+IPC_DRIVERS}};

    # Turn on polling by default, people expect it.
    $self->enable_ipc_polling;

    unless (@{$self->{+IPC_DRIVERS}}) {
        my ($ok, $error) = try { require Test2::IPC::Driver::Files };
        die $error unless $ok;
        push @{$self->{+IPC_DRIVERS}} => 'Test2::IPC::Driver::Files';
    }

    for my $driver (@{$self->{+IPC_DRIVERS}}) {
        next unless $driver->can('is_viable') && $driver->is_viable;
        $self->{+IPC} = $driver->new or next;
        return;
    }

    die "IPC has been requested, but no viable drivers were found. Aborting...\n";
}

sub formatter_set { $_[0]->{+FORMATTER} ? 1 : 0 }

sub add_formatter {
    my $self = shift;
    my ($formatter) = @_;
    unshift @{$self->{+FORMATTERS}} => $formatter;

    return unless $self->{+FINALIZED};

    # Why is the @CARP_NOT entry not enough?
    local %Carp::Internal = %Carp::Internal;
    $Carp::Internal{'Test2::Formatter'} = 1;

    carp "Formatter $formatter loaded too late to be used as the global formatter";
}

sub add_context_init_callback {
    my $self =  shift;
    my ($code) = @_;

    my $rtype = reftype($code) || "";

    confess "Context-init callbacks must be coderefs"
        unless $code && $rtype eq 'CODE';

    push @{$self->{+CONTEXT_INIT_CALLBACKS}} => $code;
}

sub add_context_release_callback {
    my $self =  shift;
    my ($code) = @_;

    my $rtype = reftype($code) || "";

    confess "Context-release callbacks must be coderefs"
        unless $code && $rtype eq 'CODE';

    push @{$self->{+CONTEXT_RELEASE_CALLBACKS}} => $code;
}

sub add_post_load_callback {
    my $self = shift;
    my ($code) = @_;

    my $rtype = reftype($code) || "";

    confess "Post-load callbacks must be coderefs"
        unless $code && $rtype eq 'CODE';

    push @{$self->{+POST_LOAD_CALLBACKS}} => $code;
    $code->() if $self->{+LOADED};
}

sub load {
    my $self = shift;
    unless ($self->{+LOADED}) {
        $self->{+LOADED} = 1;
        $_->() for @{$self->{+POST_LOAD_CALLBACKS}};
    }
    return $self->{+LOADED};
}

sub add_exit_callback {
    my $self = shift;
    my ($code) = @_;
    my $rtype = reftype($code) || "";

    confess "End callbacks must be coderefs"
        unless $code && $rtype eq 'CODE';

    push @{$self->{+EXIT_CALLBACKS}} => $code;
}

sub add_ipc_driver {
    my $self = shift;
    my ($driver) = @_;
    unshift @{$self->{+IPC_DRIVERS}} => $driver;

    return unless $self->{+FINALIZED};

    # Why is the @CARP_NOT entry not enough?
    local %Carp::Internal = %Carp::Internal;
    $Carp::Internal{'Test2::IPC::Driver'} = 1;

    carp "IPC driver $driver loaded too late to be used as the global ipc driver";
}

sub enable_ipc_polling {
    my $self = shift;

    $self->add_context_init_callback(
        # This is called every time a context is created, it needs to be fast.
        # $_[0] is a context object
        sub { $_[0]->{hub}->cull if $self->{+IPC_POLLING} }
    ) unless defined $self->ipc_polling;

    $self->set_ipc_polling(1);
}

sub disable_ipc_polling {
    my $self = shift;
    return unless defined $self->{+IPC_POLLING};
    $self->{+IPC_POLLING} = 0;
}

sub _ipc_wait {
    my $fail = 0;

    while (CAN_FORK) {
        my $pid = CORE::wait();
        my $err = $?;
        last if $pid == -1;
        next unless $err;
        $fail++;
        $err = $err >> 8;
        warn "Process $pid did not exit cleanly (status: $err)\n";
    }

    if (USE_THREADS) {
        for my $t (threads->list()) {
            $t->join;
            # In older threads we cannot check if a thread had an error unless
            # we control it and its return.
            my $err = $t->can('error') ? $t->error : undef;
            next unless $err;
            my $tid = $t->tid();
            $fail++;
            chomp($err);
            warn "Thread $tid did not end cleanly: $err\n";
        }
    }

    return 0 unless $fail;
    return 255;
}

sub set_exit {
    my $self = shift;

    my $exit     = $?;
    my $new_exit = $exit;

    my @unreleased = grep { $_ && $_->trace->pid == $$ } values %{$self->{+CONTEXTS}};
    if (@unreleased) {
        $exit = 255;
        $new_exit = 255;

        $_->trace->alert("context object was never released! This means a testing tool is behaving very badly")
            for @unreleased;
    }

    if ($self->{+PID} != $$ or $self->{+TID} != get_tid()) {
        $? = $exit;
        return;
    }

    my @hubs = $self->{+STACK} ? $self->{+STACK}->all : ();

    if (@hubs and $self->{+IPC} and !$self->{+NO_WAIT}) {
        local $?;
        my %seen;
        for my $hub (reverse @hubs) {
            my $ipc = $hub->ipc or next;
            next if $seen{$ipc}++;
            $ipc->waiting();
        }

        my $ipc_exit = _ipc_wait();
        $new_exit ||= $ipc_exit;
    }

    # None of this is necessary if we never got a root hub
    if(my $root = shift @hubs) {
        my $trace = Test2::Util::Trace->new(
            frame  => [__PACKAGE__, __FILE__, 0, __PACKAGE__ . '::END'],
            detail => __PACKAGE__ . ' END Block finalization',
        );
        my $ctx = Test2::API::Context->new(
            trace => $trace,
            hub   => $root,
        );

        if (@hubs) {
            $ctx->diag("Test ended with extra hubs on the stack!");
            $new_exit  = 255;
        }

        unless ($root->no_ending) {
            local $?;
            $root->finalize($trace) unless $root->ended;
            $_->($ctx, $exit, \$new_exit) for @{$self->{+EXIT_CALLBACKS}};
            $new_exit ||= $root->failed;
        }
    }

    $new_exit = 255 if $new_exit > 255;

    $? = $new_exit;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::API::Instance - Object used by Test2::API under the hood

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

This object encapsulates the global shared state tracked by
L<Test2>. A single global instance of this package is stored (and
obscured) by the L<Test2::API> package.

There is no reason to directly use this package. This package is documented for
completeness. This package can change, or go away completely at any time.
Directly using, or monkeypatching this package is not supported in any way
shape or form.

=head1 SYNOPSIS

    use Test2::API::Instance;

    my $obj = Test2::API::Instance->new;

=over 4

=item $pid = $obj->pid

PID of this instance.

=item $obj->tid

Thread ID of this instance.

=item $obj->reset()

Reset the object to defaults.

=item $obj->load()

Set the internal state to loaded, and run and stored post-load callbacks.

=item $bool = $obj->loaded

Check if the state is set to loaded.

=item $arrayref = $obj->post_load_callbacks

Get the post-load callbacks.

=item $obj->add_post_load_callback(sub { ... })

Add a post-load callback. If C<load()> has already been called then the callback will
be immedietly executed. If C<load()> has not been called then the callback will be
stored and executed later when C<load()> is called.

=item $hashref = $obj->contexts()

Get a hashref of all active contexts keyed by hub id.

=item $arrayref = $obj->context_init_callbacks

Get all context init callbacks.

=item $arrayref = $obj->context_release_callbacks

Get all context release callbacks.

=item $obj->add_context_init_callback(sub { ... })

Add a context init callback. Subs are called every time a context is created. Subs
get the newly created context as their only argument.

=item $obj->add_context_release_callback(sub { ... })

Add a context release callback. Subs are called every time a context is released. Subs
get the released context as their only argument. These callbacks should not
call release on the context.

=item $obj->set_exit()

This is intended to be called in an C<END { ... }> block. This will look at
test state and set $?. This will also call any end callbacks, and wait on child
processes/threads.

=item $drivers = $obj->ipc_drivers

Get the list of IPC drivers.

=item $obj->add_ipc_driver($DRIVER_CLASS)

Add an IPC driver to the list. The most recently added IPC driver will become
the global one during initialization. If a driver is added after initialization
has occured a warning will be generated:

    "IPC driver $driver loaded too late to be used as the global ipc driver"

=item $bool = $obj->ipc_polling

Check if polling is enabled.

=item $obj->enable_ipc_polling

Turn on polling. This will cull events from other processes and threads every
time a context is created.

=item $obj->disable_ipc_polling

Turn off IPC polling.

=item $bool = $obj->no_wait

=item $bool = $obj->set_no_wait($bool)

Get/Set no_wait. This option is used to turn off process/thread waiting at exit.

=item $arrayref = $obj->exit_callbacks

Get the exit callbacks.

=item $obj->add_exit_callback(sub { ... })

Add an exit callback. This callback will be called by C<set_exit()>.

=item $bool = $obj->finalized

Check if the object is finalized. Finalization happens when either C<ipc()>,
C<stack()>, or C<format()> are called on the object. Once finalization happens
these fields are considered unchangeable (not enforced here, enforced by
L<Test2>).

=item $ipc = $obj->ipc

Get the one true IPC instance.

=item $stack = $obj->stack

Get the one true hub stack.

=item $formatter = $obj->formatter

Get the global formatter. By default this is the C<'Test2::Formatter::TAP'>
package. This could be any package that implements the C<write()> method. This
can also be an instantiated object.

=item $bool = $obj->formatter_set()

Check if a formatter has been set.

=item $obj->add_formatter($class)

=item $obj->add_formatter($obj)

Add a formatter. The most recently added formatter will become the global one
during initialization. If a formatter is added after initialization has occured
a warning will be generated:

    "Formatter $formatter loaded too late to be used as the global formatter"

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

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
