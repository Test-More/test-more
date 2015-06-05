package Test::Stream::Event;
use strict;
use warnings;

use Carp qw/confess/;

use Test::Stream::HashBase(
    accessors => [qw/debug nested/],
);

sub import {
    my $class = shift;

    # Import should only when event is imported, subclasses do not use this
    # import.
    return if $class ne __PACKAGE__;

    my $caller = caller;
    my (%args) = @_;

    my $accessors = $args{accessors} || [];

    # %args may override base
    Test::Stream::HashBase->import(into => $caller, base => $class, %args);
}

sub init {
    confess("No debug info provided!") unless $_[0]->{+DEBUG};
}

sub update_state { }

sub terminate { undef }

sub global { 0 }

sub subevents { }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event - Base class for events

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test::Stream>.

=head1 SYNOPSIS

    package Test::Stream::Event::MyEvent;
    use strict;
    use warnings;

    # This will make our class an event subclass, add the specified accessors,
    # add constants for all our fields, and fields we inherit.
    use Test::Stream::Event(
        accessors  => [qw/foo bar baz/],
    );

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

=head1 IMPORTING

=head2 ARGUMENTS

In addition to the arguments listed here, you may pass in any arguments
accepted by L<Test::Stream::HashBase>.

=over 4

=item base => $BASE_CLASS

This lets you specify an event class to subclass. B<THIS MUST BE AN EVENT
CLASS>. If you do not specify anything here then C<Test::Stream::Event> will be
used.

=item accessors => \@FIELDS

This lets you define any fields you wish to be present in your class. This is
the only way to define storage for your event. Each field specified will get a
read-only accessor with the same name as the field, as well as a setter
C<set_FIELD()>. You will also get a constant that returns the index of the
field in the classes arrayref. The constant is the name of the field in all
upper-case.

=back

=head2 SUBCLASSING

C<Test::Stream::Event> is added to your @INC for you, unless you specify an
alternative base class, which must itself subclass C<Test::Stream::Event>.

=head1 METHODS

=over 4

=item $dbg = $e->debug

Get a snapshot of the debug info as it was when this event was generated

=item $call = $e->created

Get the C<caller()> details from when the event was generated. This is usually
inside a tools package. This is typically used for debugging.

=item $num = $e->nested

If this event is nested inside of other events, this should be the depth of
nesting. (This is mainly for subtests)

=item @events = $e->subevents

If the event type can encapsulate other events, thisis how you retrieve them.
This will return an empty list for other events.

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
