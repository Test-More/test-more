package Test::Stream::Sync;
use strict;
use warnings;

use Carp qw/croak/;

use Test::Stream::SyncObj;

my $INST = Test::Stream::SyncObj->new;

sub pid       { $INST->pid }
sub tid       { $INST->tid }
sub stack     { $INST->stack }
sub ipc       { $INST->ipc }
sub formatter { $INST->format }
sub init_done { $INST->finalized }

sub hooks      { scalar @{$INST->exit_hooks} }
sub post_loads { scalar @{$INST->post_load_hooks} }

sub post_load {
    my $class = shift;
    $INST->add_post_load_hook(@_);
}

sub loaded {
    my $class = shift;
    my $loaded = $INST->loaded;
    return $loaded if $loaded || !$_[0];
    $INST->load;
}

sub add_hook {
    my $class = shift;
    $INST->add_exit_hook(@_);
}

sub set_formatter {
    my $class = shift;
    my ($format) = @_;
    croak "No formatter specified" unless $format;
    croak "Global Formatter already set" if $INST->format_set;
    $INST->set_format($format);
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

Test::Stream::Sync - Primary Synchronization point, this is where global stuff
lives.

=head1 ***INTERNALS NOTE***

B<The internals of this package are subject to change at any time!> The public
methods provided will not change in backwords incompatible ways, but the
underlying implementation details might. B<Do not break encapsulation here!>

Currently the implementation is to create a single instance of the
L<Test::Stream::SyncObj> Object. All class methods defer to the single
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

    use Test::Stream::Sync; # No Exports

    my $init  = Test::Stream::Sync->init_done;
    my $stack = Test::Stream::Sync->stack;
    my $ipc   = Test::Stream::Sync->ipc;

    Test::Stream::Sync->set_formatter($FORMATTER)
    my $formatter = Test::Stream::Sync->formatter;

=head1 CLASS METHODS

This class stores global instances of things. This package is NOT an object,
everything that uses it will get the same stuff.

=over 4

=item $bool = Test::Stream::Sync->init_done

This will return true if the stack and ipc instances have already been
initialized. It will return false if they have not.

=item $stack = Test::Stream::Sync->stack

This will return the global L<Test::Stream::Stack> instance. If this has not
yet been initialized it will be initialized now.

=item $ipc = Test::Stream::Sync->ipc

This will return the global L<Test::Stream::IPC> instance. If this has not yet
been initialized it will be initialized now.

=item $formatter = Test::Stream::Sync->formatter

This will return the global formatter class. This is not an instance. By
default the formatter is set to L<Test::Stream::Formatter::TAP>.

You can override this default using the C<TS_FORMATTER> environment variable.

Normally 'Test::Stream::Formatter::' is prefixed to the value in the
environment variable:

    $ TS_FORMATTER='TAP' perl test.t     # Use the Test::Stream::Formatter::TAP formatter
    $ TS_FORMATTER='Foo' perl test.t     # Use the Test::Stream::Formatter::Foo formatter

If you want to specify a full module name you use the '+' prefix:

    $ TS_FORMATTER='+Foo::Bar' perl test.t     # Use the Foo::Bar formatter

=item Test::Stream::Sync->set_formatter($class)

Set the global formatter class. This can only be set once. B<Note:> This will
override anything specified in the 'TS_FORMATTER' environment variable.

=item $bool = Test::Stream::Sync->no_wait

=item Test::Stream::Sync->no_wait($bool)

This can be used to get/set the no_wait status. Waiting is turned on by
default. Waiting will cause the parent process/thread to wait until all child
processes and threads are finished before exiting. You will almost never want
to turn this off.

=item Test::Stream::Sync->add_hook(sub { ... })

This can be used to add a hook that is called after all testing is done. This
is too late to add additional results, the main use of this hook is to set the
exit code.

    Test::Stream::Sync->add_hook(
        sub {
            my ($context, $exit, \$new_exit) = @_;
            ...
        }
    );

The C<$context> passed in will be an instance of L<Test::Stream::Context>. The
C<$exit> argument will be the original exit code before anything modified it.
C<$$new_exit> is a reference to the new exit code. You may modify this to
change the exit code. Please note that C<$$new_exit> may already be different
from C<$exit>

=item Test::Stream::Sync->post_load(sub { ... })

Add a callback that will be called when Test::Stream is finished loading. This
means the callback will be run when Test::Stream is done loading all the
plugins in your use statement. If Test::Stream has already finished loading
then the callback will be run immedietly.

=item $bool = Test::Stream::Sync->loaded

=item Test::Stream::Sync->loaded($true)

Without arguments this will simply return the boolean value of the loaded flag.
If Test::Stream has finished loading this will be true, otherwise false. If a
true value is provided as an argument then this will set the flag to true, and
run all C<post_load> callbacks. The second form should B<ONLY> ever be used in
L<Test::Stream> or alternative loader modules.

=back

=head1 MAGIC

This package has an END block. This END block is responsible for setting the
exit code based on the test results. This end block also calls the hooks that
can be added to this package.

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

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
