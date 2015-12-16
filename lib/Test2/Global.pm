package Test2::Global;
use strict;
use warnings;

use Carp qw/croak/;

use Test2::Global::Instance;

my $INST = Test2::Global::Instance->new;
sub _internal_use_only_private_instance { $INST }

sub pid       { $INST->pid }
sub tid       { $INST->tid }
sub stack     { $INST->stack }
sub ipc       { $INST->ipc }
sub formatter { $INST->formatter }
sub init_done { $INST->finalized }
sub load_done { $INST->loaded }

sub enable_ipc_polling  { $INST->enable_ipc_polling }
sub disable_ipc_polling { $INST->disable_ipc_polling }

sub add_ipc_driver { shift; $INST->add_ipc_driver(@_) }
sub ipc_drivers    { @{$INST->ipc_drivers} }
sub ipc_polling    { $INST->ipc_polling }

sub add_context_init_callback    { shift; $INST->add_context_init_callback(@_) }
sub add_context_release_callback { shift; $INST->add_context_release_callback(@_) }
sub add_post_load_callback       { shift; $INST->add_post_load_callback(@_) }
sub add_exit_callback            { shift; $INST->add_exit_callback(@_) }

sub add_formatter { shift; $INST->add_formatter(@_) }
sub formatters    { @{$INST->formatters} }

sub set_formatter {
    my $class = shift;
    my ($formater) = @_;
    croak "No formatter specified" unless $formater;
    croak "Global Formatter already set" if $INST->formatter_set;
    $INST->set_format($formater);
}

sub no_wait {
    my $class = shift;
    $INST->set_no_wait(@_) if @_;
    $INST->no_wait;
}

# Set the exit status
END { $INST->set_exit() }

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
methods provided will not change in backwords incompatible ways, but the
underlying implementation details might. B<Do not break encapsulation here!>

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

    use Test2::Global; # No Exports

    my $init  = Test2::Global->init_done;
    my $stack = Test2::Global->stack;
    my $ipc   = Test2::Global->ipc;

    Test2::Global->set_formatter($FORMATTER)
    my $formatter = Test2::Global->formatter;

=head1 CLASS METHODS

This class stores global instances of things. This package is NOT an object,
everything that uses it will get the same stuff.

=over 4

=item $bool = Test2::Global->init_done

This will return true if the stack and ipc instances have already been
initialized. It will return false if they have not. Init happens as late as
possible, it happens as soon as a tool requests the ipc instance, the
formatter, or the stack. 

=item $bool = Test2::Global->load_done

This will simply return the boolean value of the loaded flag. If Test2 has
finished loading this will be true, otherwise false. Loading is considered
complete the first time a tool requests a context.

=item $stack = Test2::Global->stack

This will return the global L<Test2::Context::Stack> instance. If this has not
yet been initialized it will be initialized now.

=item $ipc = Test2::Global->ipc

This will return the global L<Test2::IPC::Driver> instance. If this has not yet
been initialized it will be initialized now.

=item Test2::Global->add_ipc_driver($DRIVER)

Add an IPC driver to the list. This will add the driver to the start of the
list.

=item @drivers = Test2::Global->ipc_drivers

Get the list of IPC drivers.

=item $bool = Test2::Global->ipc_polling

Check if polling is enabled.

=item Test2::Global->enable_ipc_polling

Turn on polling. This will cull events from other processes and threads every
time a context is created.

=item Test2::Global->disable_ipc_polling

Turn off IPC polling.

=item $formatter = Test2::Global->formatter

This will return the global formatter class. This is not an instance. By
default the formatter is set to L<Test2::Formatter::TAP>.

You can override this default using the C<TS_FORMATTER> environment variable.

Normally 'Test2::Formatter::' is prefixed to the value in the
environment variable:

    $ TS_FORMATTER='TAP' perl test.t     # Use the Test2::Formatter::TAP formatter
    $ TS_FORMATTER='Foo' perl test.t     # Use the Test2::Formatter::Foo formatter

If you want to specify a full module name you use the '+' prefix:

    $ TS_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

=item Test2::Global->set_formatter($class)

Set the global formatter class. This can only be set once. B<Note:> This will
override anything specified in the 'TS_FORMATTER' environment variable.

=item $bool = Test2::Global->no_wait

=item Test2::Global->no_wait($bool)

This can be used to get/set the no_wait status. Waiting is turned on by
default. Waiting will cause the parent process/thread to wait until all child
processes and threads are finished before exiting. You will almost never want
to turn this off.

=item Test2::Global->add_exit_callback(sub { ... })

This can be used to add a callback that is called after all testing is done. This
is too late to add additional results, the main use of this callback is to set the
exit code.

    Test2::Global->add_callback(
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

=item Test2::Global->add_post_load_callback(sub { ... })

Add a callback that will be called when Test2 is finished loading. This
means the callback will be run once, the first time a context is obtained.
If Test2 has already finished loading then the callback will be run immedietly.

=item Test2::Global->add_context_init_callback(sub { ... })

Add a callback that will be called every time a new context is created. The
callback will recieve the newly created context as its only argument.

=item Test2::Global->add_context_release_callback(sub { ... })

Add a callback that will be called every time a context is released. The
callback will recieve the released context as its only argument.

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
