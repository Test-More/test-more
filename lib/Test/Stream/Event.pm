package Test::Stream::Event;
use strict;
use warnings;

use Carp qw/confess carp/;

use Test::Stream::HashBase(
    accessors => [qw/debug nested/],
);

sub import {
    my $class = shift;

    # Import should only when event is imported, subclasses do not use this
    # import.
    return if $class ne __PACKAGE__;

    carp "The magical 'import' method on $class is deprecated and will be removed in the near future.";

    my $caller = caller;
    my (%args) = @_;

    my $accessors = $args{accessors} || [];

    # %args may override base
    Test::Stream::HashBase->import(into => $caller, base => $class, %args);
}

sub init {
    confess("No debug info provided!") unless $_[0]->{+DEBUG};
}

sub causes_fail  { 0 }

sub update_state {()};
sub terminate    {()};
sub global       {()};

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    carp 'Use of $event->to_tap is deprecated';

    require Test::Stream::Formatter::TAP;
    my $formatter = Test::Stream::Formatter::TAP->new;
    $formatter->event_tap($self, $num);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event - Base class for events

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test::Stream>.

=head1 SYNOPSIS

    package Test::Stream::Event::MyEvent;
    use strict;
    use warnings;

    # This will make our class an event subclass (required)
    use base 'Test::Stream::Event';

    # Add some accessors
    use Test::Stream::HashBase accessors => [qw/foo bar baz/];

    # Chance to initialize some defaults
    sub init {
        my $self = shift;
        # no other args in @_

        $self->SUPER::init();

        $self->set_foo('xxx') unless defined $self->foo;

        # Events are arrayrefs, all accessors have a constant defined with
        # their index.
        $self->[BAR] ||= "";

        ...
    }

    1;

=head1 METHODS

=over 4

=item $dbg = $e->debug

Get a snapshot of the debug info as it was when this event was generated

=item $bool = $e->causes_fail

Returns true if this event should result in a test failure. In general this
should be false.

=item $call = $e->created

Get the C<caller()> details from when the event was generated. This is usually
inside a tools package. This is typically used for debugging.

=item $num = $e->nested

If this event is nested inside of other events, this should be the depth of
nesting. (This is mainly for subtests)

=item $e->update_state($state)

This callback is used by L<Test::Stream::Hub> to give your event a chance to
update the state.

This is called B<BEFORE> your event is passed to the formatter.

=item $bool = $e->global

Set this to true if your event is global, that is ALL threads and processes
should see it no matter when or where it is generated. This is not a common
thing to want, it is used by bail-out and skip_all to end testing.

=item $code = $e->terminate

This is called B<AFTER> your event has been passed to the formatter. This
should normally return undef, only change this if your event should cause the
test to exit immedietly.

If you want this event to cause the test to exit you should return the exit
code here. Exit code of 0 means exit success, any other integer means exit with
failure.

This is used by L<Test::Stream::Event::Plan> to exit 0 when the plan is
'skip_all'. This is also used by L<Test::Stream::Event:Bail> to force the test
to exit with a failure.

This is called after the event has been sent to the formatter in order to
ensure the event is seen and understood.

=item @output = $e->to_tap($num)

B<***DEPRECATED***> This will be removed in the near future. See
L<Test::Stream::Formatter::TAP> for TAP production.

This is where you get the chance to produce TAP output. The input argument
C<$num> will either be the most recent test number, or undefined. The output
should be a list of arrayrefs, each arrayref should have exactly 2 values:
C<$HID, $TEXT>. The HID tells the formatter which output handle to use (see the
constants provided by L<Test::Stream::Formatter::TAP>), C<$TEXT> should be the text that
is output to the specified handle.

Example:

    package Test::Stream::Event::MyEvent;
    use base 'Test::Stream::Event';
    use Test::Stream::Formatter::TAP qw/OUT_STD OUT_TODO OUT_ERR/;

    sub to_tap {
        my $self = shift;
        my ($num) = @_;

        # Using test numbers
        if (defined $num) {
            return (
                [OUT_STD, "# Got MyEvent!"],
                [OUT_ERR, "# The last test was $num"],
            );
        }

        # Not using test numbers.
        return (
            [OUT_STD, "# Got MyEvent!"],
        );
    }

=back

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
