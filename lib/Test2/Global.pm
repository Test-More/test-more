package Test2::Global;
use strict;
use warnings;

use base 'Exporter';
our @EXPORT_OK = qw{
    test2_init_done
    test2_load_done

    test2_pid
    test2_tid
    test2_stack
    test2_no_wait

    test2_add_callback_context_init
    test2_add_callback_context_release
    test2_add_callback_exit
    test2_add_callback_post_load

    test2_ipc
    test2_ipc_drivers
    test2_ipc_add_driver
    test2_ipc_polling
    test2_ipc_disable_polling
    test2_ipc_enable_polling

    test2_formatter
    test2_formatters
    test2_formatter_add
    test2_formatter_set
};

use Carp qw/croak/;

use Test2::Global::Instance;

my $INST = Test2::Global::Instance->new;
sub _internal_use_only_private_instance { $INST }

# Set the exit status
END { $INST->set_exit() }

sub test2_init_done { $INST->finalized }
sub test2_load_done { $INST->loaded }

sub test2_pid     { $INST->pid }
sub test2_tid     { $INST->tid }
sub test2_stack   { $INST->stack }
sub test2_no_wait {
    $INST->set_no_wait(@_) if @_;
    $INST->no_wait;
}

sub test2_add_callback_context_init    { $INST->add_context_init_callback(@_) }
sub test2_add_callback_context_release { $INST->add_context_release_callback(@_) }
sub test2_add_callback_post_load       { $INST->add_post_load_callback(@_) }
sub test2_add_callback_exit            { $INST->add_exit_callback(@_) }

sub test2_ipc                 { $INST->ipc }
sub test2_ipc_add_driver      { $INST->add_ipc_driver(@_) }
sub test2_ipc_drivers         { @{$INST->ipc_drivers} }
sub test2_ipc_polling         { $INST->ipc_polling }
sub test2_ipc_enable_polling  { $INST->enable_ipc_polling }
sub test2_ipc_disable_polling { $INST->disable_ipc_polling }

sub test2_formatter     { $INST->formatter }
sub test2_formatters    { @{$INST->formatters} }
sub test2_formatter_add { $INST->add_formatter(@_) }
sub test2_formatter_set {
    my ($formater) = @_;
    croak "No formatter specified" unless $formater;
    croak "Global Formatter already set" if $INST->formatter_set;
    $INST->set_formatter($formater);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Global - Primary Synchronization point, this is where global stuff
lives.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 ***INTERNALS NOTE***

B<The internals of this package are subject to change at any time!> The public
methods provided will not change in backwords incompatible ways (once there is
a stable release), but the underlying implementation details might.
B<Do not break encapsulation here!>

Currently the implementation is to create a single instance of the
L<Test2::Global::Instance> Object. All class methods defer to the single
instance. There is no public access to the singleton, and that is intentional.
The class methods provided by this package provide the only functionality
publicly exposed.

This is done primarily to avoid the problems Test::Builder had by exposing its
singleton. We do not want anyone to replace this singleton, rebless it, or
directly muck with its internals. If you need to do something, and cannot
because of the restrictions placed here then please report it as an issue. If
possible we will create a way for you to implement your functionality without
exposing things that should not be exposed.

=head1 DESCRIPTION

There is a need to synchronize some details for all tests that run. This
package stores these global objects. As little as possible is kept here, when
possible things should not be global.

=head1 SYNOPSIS

    use Test2::Global qw{
        test2_init_done
        test2_stack
        test2_ipc
        test2_formatter_set
        test2_formatter
    };

    my $init  = test2_init_done();
    my $stack = test2_stack();
    my $ipc   = test2_ipc();

    test2_formatter_set($FORMATTER)
    my $formatter = test2_formatter();

    ... And others ...

=head1 EXPORTS

All exports are optional, you must specify ones you want.

=head2 STATUS AND INITIALIZATION STATE

These provide access to internal state and object instances.

=over 4

=item $bool = test2_init_done()

This will return true if the stack and ipc instances have already been
initialized. It will return false if they have not. Init happens as late as
possible, it happens as soon as a tool requests the ipc instance, the
formatter, or the stack.

=item $bool = test2_load_done()

This will simply return the boolean value of the loaded flag. If Test2 has
finished loading this will be true, otherwise false. Loading is considered
complete the first time a tool requests a context.

=item $stack = test2_stack()

This will return the global L<Test2::Context::Stack> instance. If this has not
yet been initialized it will be initialized now.

=item $bool = test2_no_wait()

=item test2_no_wait($bool)

This can be used to get/set the no_wait status. Waiting is turned on by
default. Waiting will cause the parent process/thread to wait until all child
processes and threads are finished before exiting. You will almost never want
to turn this off.

=back

=head2 BEHAVIOR HOOKS

These are hooks that allow you to add custom behavior to actions taken by Test2
and tools built on top of it.

=over 4

=item test2_add_callback_exit(sub { ... })

This can be used to add a callback that is called after all testing is done. This
is too late to add additional results, the main use of this callback is to set the
exit code.

    test2_add_callback_exit(
        sub {
            my ($context, $exit, \$new_exit) = @_;
            ...
        }
    );

The C<$context> passed in will be an instance of L<Test2::Context>. The
C<$exit> argument will be the original exit code before anything modified it.
C<$$new_exit> is a reference to the new exit code. You may modify this to
change the exit code. Please note that C<$$new_exit> may already be different
from C<$exit>

=item test2_add_callback_post_load(sub { ... })

Add a callback that will be called when Test2 is finished loading. This
means the callback will be run once, the first time a context is obtained.
If Test2 has already finished loading then the callback will be run immedietly.

=item test2_add_callback_context_init(sub { ... })

Add a callback that will be called every time a new context is created. The
callback will recieve the newly created context as its only argument.

=item test2_add_callback_context_release(sub { ... })

Add a callback that will be called every time a context is released. The
callback will recieve the released context as its only argument.

=back

=head2 IPC AND CONCURRENCY

These let you access, or specify, the IPC system internals.

=over 4

=item $ipc = test2_ipc()

This will return the global L<Test2::IPC::Driver> instance. If this has not yet
been initialized it will be initialized now.

=item test2_ipc_add_driver($DRIVER)

Add an IPC driver to the list. This will add the driver to the start of the
list.

=item @drivers = test2_ipc_drivers()

Get the list of IPC drivers.

=item $bool = test2_ipc_polling()

Check if polling is enabled.

=item test2_ipc_enable_polling()

Turn on polling. This will cull events from other processes and threads every
time a context is created.

=item test2_ipc_disable_polling()

Turn off IPC polling.

=back

=head2 MANAGING FORMATTERS

These let you access, or specify, the formatters that can/should be used.

=over 4

=item $formatter = test2_formatter

This will return the global formatter class. This is not an instance. By
default the formatter is set to L<Test2::Formatter::TAP>.

You can override this default using the C<T2_FORMATTER> environment variable.

Normally 'Test2::Formatter::' is prefixed to the value in the
environment variable:

    $ T2_FORMATTER='TAP' perl test.t     # Use the Test2::Formatter::TAP formatter
    $ T2_FORMATTER='Foo' perl test.t     # Use the Test2::Formatter::Foo formatter

If you want to specify a full module name you use the '+' prefix:

    $ T2_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

=item test2_formatter_set($class_or_instance)

Set the global formatter class. This can only be set once. B<Note:> This will
override anything specified in the 'T2_FORMATTER' environment variable.

=item @formatters = test2_formatters()

Get a list of all loaded formatters.

=item test2_formatter_add($class_or_instance)

Add a formatter to the list. Last formatter added is used at initialization. If
this is called after initialization a warning will be issued.

=back

=head1 MAGIC

This package has an END block. This END block is responsible for setting the
exit code based on the test results. This end block also calls the callbacks that
can be added to this package.

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
