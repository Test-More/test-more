package Test2::Event;
use strict;
use warnings;

use Test2::Util::HashBase qw/trace nested _meta/;

sub causes_fail      { 0 }
sub increments_count { 0 }

sub callback { }

sub terminate { () }
sub global    { () }

sub set_meta {
    my $self = shift;
    my ($key, $value) = @_;

    $self->{+_META} ||= {};

    $self->{+_META}->{$key} = $value;
}

sub get_meta {
    my $self = shift;
    my ($key, $default) = @_;

    return undef unless $self->{+_META} || $default;

    $self->{+_META} ||= {};

    $self->{+_META}->{$key} = $default
        if defined($default) && !defined($self->{+_META}->{$key});

    return $self->{+_META}->{$key};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event - Base class for events

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test2>.

=head1 SYNOPSIS

    package Test2::Event::MyEvent;
    use strict;
    use warnings;

    # This will make our class an event subclass (required)
    use base 'Test2::Event';

    # Add some accessors (optional)
    # You are not obligated to use HashBase, you can use any object tool you
    # want, or roll your own accessors.
    use Test2::Util::HashBase qw/foo bar baz/;

    # Chance to initialize some defaults
    sub init {
        my $self = shift;
        # no other args in @_

        $self->set_foo('xxx') unless defined $self->foo;

        ...
    }

    1;

=head1 METHODS

=over 4

=item $trace = $e->trace

Get a snapshot of the L<Test2::Util::Trace> as it was when this event was
generated

=item $bool = $e->causes_fail

Returns true if this event should result in a test failure. In general this
should be false.

=item $bool = $e->increments_count

Should be true if this event should result in a test count increment.

=item $e->callback($hub)

If your event needs to have extra effects on the L<Test2::Hub> you can override
this method.

This is called B<BEFORE> your event is passed to the formatter.

=item $call = $e->created

Get the C<caller()> details from when the event was generated. This is usually
inside a tools package. This is typically used for debugging.

=item $num = $e->nested

If this event is nested inside of other events, this should be the depth of
nesting. (This is mainly for subtests)

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

This is used by L<Test2::Event::Plan> to exit 0 when the plan is
'skip_all'. This is also used by L<Test2::Event:Bail> to force the test
to exit with a failure.

This is called after the event has been sent to the formatter in order to
ensure the event is seen and understood.

=item $e->set_meta($key, $val)

Some plugins may want to attach information to an event. This is a generic way
to do that. C<$key> should be chosen likely, and is ideally prefixed with a
package name to avoid conflicts.

    $e->set_meta('Foo::Bar', { a => 1 });

=item $e->get_meta($key)

=item $e->get_meta($key, $default)

This how you read meta data that is attached to an event. The key should match
that used when the meta-data was set. Ideally keys are prefixed with package
names to avoid conflicts.

    # Get the value, or undef if there is none.
    my $val = $e->get_meta('Foo::Bar');

A default value can be specified as well. If there is no value attached to the
event then the default will be attached and returned.

    # Get the value, or set it to 'xxx' and get that.
    my $val = $e->get_meta('Foo::Bar', 'xxx');

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
