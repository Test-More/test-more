package Test::Stream::Tester;
use strict;
use warnings;

use Scalar::Util qw/reftype/;
use Carp qw/croak/;

use Test::Stream::DeepCheck::Util qw/yada render_var/;
use Test::Stream::Interceptor qw/grab intercept/;
use Test::Stream::DeepCheck qw{
    STRUCT
    build_object
    call=event_call
    field=event_field
    relaxed_compare=events_are
    array=events
    end=end_events
    convert
    filter=filter_events
};

use Test::Stream::Exporter;
default_exports qw{
    grab intercept
    event
    event_call event_field
    event_line event_file event_package event_sub event_trace
    event_todo event_skip
    events_are events
    end_events
    filter_events
};
no Test::Stream::Exporter;

sub event($$) {
    my ($type, $guts) = @_;

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check;

    my $rtype = reftype $guts || '';
    if ($rtype eq 'HASH') {
        $check = convert($guts, $dbg);
    }
    elsif($rtype eq 'CODE') {
        $check = build_object('Test::Stream::DeepCheck::Object::Hash', $guts, [caller]);
    }
    else {
        croak "Second argument to event() must be a hashref or a coderef, got " . defined($guts) ? $guts : 'undef';
    }

    croak "event check must be either a hashref or a 'Test::Stream::DeepCheck::Hash'"
        unless $check->isa('Test::Stream::DeepCheck::Hash');

    $check->add_meta(
        'Event Type',
        Test::Stream::DeepCheck::Check->new(
            op    => 'isa',
            val   => "Test::Stream::Event::$type",
            debug => $dbg,
        ),
    );

    return $check if defined wantarray;

    $check->set__builder(1);

    my $array = STRUCT();
    croak "event() was called in a void context, but no build is on the stack!"
        unless $array;

    croak "event() was called in a void context, but the top of the build stack is not an array!"
        unless $array->isa('Test::Stream::DeepCheck::Array');

    $array->add_element($check);
}

sub event_line($) {
    my ($val) = @_;

    croak "event_line() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_line() was called with no event on the stack!"
        unless $event;

    croak "event_line() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { $_[0]->debug->line == $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->line);
            $want = render_var($want);

            my $short = "$got == $want";
            return $short if length($short) <= 60;
            return "... == ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event Line', $check);
}

sub event_file($) {
    my ($val) = @_;

    croak "event_file() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_file() was called with no event on the stack!"
        unless $event;

    croak "event_file() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { $_[0]->debug->file eq $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->file, 1);
            $want = render_var($want, 1);

            my $short = "$got eq $want";
            return $short if length($short) <= 60;
            return "... eq ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event File', $check);
}

sub event_package($) {
    my ($val) = @_;

    croak "event_package() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_package() was called with no event on the stack!"
        unless $event;

    croak "event_package() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { $_[0]->debug->package eq $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->package, 1);
            $want = render_var($want, 1);

            my $short = "$got eq $want";
            return $short if length($short) <= 60;
            return "... eq ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event Package', $check);
}

sub event_sub($) {
    my ($val) = @_;

    croak "event_sub() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_sub() was called with no event on the stack!"
        unless $event;

    croak "event_sub() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { $_[0]->debug->subname eq $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->subname, 1);
            $want = render_var($want, 1);

            my $short = "$got eq $want";
            return $short if length($short) <= 60;
            return "... eq ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event Sub', $check);
}

sub event_trace($) {
    my ($val) = @_;

    croak "event_trace() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_trace() was called with no event on the stack!"
        unless $event;

    croak "event_trace() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { $_[0]->debug->trace eq $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->trace, 1);
            $want = render_var($want, 1);

            my $short = "$got eq $want";
            return $short if length($short) <= 60;
            return "... eq ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event Sub', $check);
}

sub event_todo($) {
    my ($val) = @_;

    croak "event_todo() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_todo() was called with no event on the stack!"
        unless $event;

    croak "event_todo() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { no warnings 'uninitialized'; $_[0]->debug->todo eq $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->todo, 1);
            $want = render_var($want, 1);

            my $short = "$got eq $want";
            return $short if length($short) <= 60;
            return "... eq ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event Todo', $check);
}

sub event_skip($) {
    my ($val) = @_;

    croak "event_skip() should only ever be called in a void context"
        if defined wantarray;

    my $event = STRUCT();
    croak "event_skip() was called with no event on the stack!"
        unless $event;

    croak "event_skip() was called but the top of the build stack is not an event!"
        unless $event->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = Test::Stream::DeepCheck::Check->new(
        debug => $dbg,
        val   => $val,
        op    => sub { no warnings 'uninitialized'; $_[0]->debug->skip eq $_[1] },
        build_diag => sub {
            my ($op, $got, $want) = @_;
            $got  = render_var($got->debug->skip, 1);
            $want = render_var($want, 1);

            my $short = "$got eq $want";
            return $short if length($short) <= 60;
            return "... eq ...\n  Expected: $want\n       Got: $got";
        },
    );

    $check->set__builder(1);

    $event->add_meta('Event Skip', $check);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Tester - Tools for validating testing tools.

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

This library provides tools that make it easy to validate your testing tools.
If you are writing a L<Test::Stream> based testing tool, this is the library
you should use to test it.

=head1 SYNOPSIS

    use Test::Stream;
    use Test::Stream::Tester;

    events_are(
        intercept {
            ok(1, 'pass');
            ok(0, 'fail');
            diag "foo";
            note "bar";
            done_testing;
        },
        events {
            event Ok => sub {
                event_call pass => 1;
                event_field effective_pass => 1;
                event_line 42;
            };
            event Ok => sub {
                event_call pass => 0;
                event_field effective_pass => 0;
                event_line 43;
                event_call diag => [ qr/Failed test 'fail'/ ]
            };
            event Diag => { message => 'foo' };
            event Note => { message => 'bar' };
            event Plan => { max => 2 };
            end_events;
        },
        "Basic check of events"
    );

=head1 EXPORTS

=head2 ASSERTIONS

=over 4

=item events_are($events, $checks, $name);

This is actually C<relaxed_compare()> from L<Test::Stream::DeepCheck>, but this
is an implementation detail you should not rely on.

C<events_are()> compares the events provided in the first argument against the
event checks in the second argument. The second argument may be a an arrayref
with hashrefs to define the events, or it can use a check constructed to
provide extra debugging details.

=back

=head2 CAPTURING EVENTS

Both of these are re-exported from L<Test::Stream::Interceptor>.

=over 4

=item $events = intercept { ... }

This lets you intercept all events inside the codeblock. All the events will be
returned in an arrayref.

    my $events = intercept {
        ok(1, 'foo');
        ok(0, 'bar');
    };
    is(@$events, 2, "intercepted 2 events.");

There are also 2 named parameters passed in, C<context> and C<hub>. The
C<context> passed in is a snapshot of the context for the C<intercept()> tool
itself, referencing the parent hub. The C<hub> parameter is the new hub created
for the C<intercept> run.

    my $events = intercept {
        my %params = @_;

        my $outer_ctx = $params{context};
        my $our_hub   = $params{hub};

        ...
    };

By default the hub used has C<no_ending> set to true. This will prevent the hub
from enforcing that you issued a plan and ran at least 1 test. You can turn
enforcement back one like this:

    my %params = @_;
    $params{hub}->set_no_ending(0);

With C<no_ending> turned off, C<$hub->finalize()> will run the post-test checks
to enforce the plan and that tests were run. In many cases this will result in
additional events in your events array.

=item $grab = grab()

This lets you intercept all events for a section of code without adding
anything to your call stack. This is useful for things that are sensitive to
changes in the stack depth.

    my $grab = grab();
        ok(1, 'foo');
        ok(0, 'bar');

    # $grab is magically undef after this.
    my $events = $grab->finish;

    is(@$events, 2, "grabbed 2 events.");

When you call C<finish()> the C<$grab> object will automagically undef itself,
but only for the reference used in the method call. If you have other
references to the C<$grab> object they will not be undef'd.

If the C<$grab> object is destroyed without calling C<finish()>, it will
automatically clean up after itself and restore the parent hub.

    {
        my $grab = grab();
        # Things are grabbed
    }
    # Things are back to normal

By default the hub used has C<no_ending> set to true. This will prevent the hub
from enforcing that you issued a plan and ran at least 1 test. You can turn
enforcement back one like this:

    $grab->hub->set_no_ending(0);

With C<no_ending> turned off, C<finish> will run the post-test checks to
enforce the plan and that tests were run. In many cases this will result in
additional events in your events array.

=back

=head2 DEFINING EVENTS

=over 4

=item events { ... }

This runs the codeblock to build an arrayref of event checks. Within the
codeblock you should call the other functions in this section to define each
event.

=item event $TYPE => \%SPEC

=item event $TYPE => sub { ... }

This is how you build an event check. The C<$TYPE> should be the final part of
the Test::Stream::Event::HERE package name. You can define the event using
either a hashref of fields, or a codeblock that calls other functions in this
section to define checks.

=item event_call $METHOD => $EXPECT

This lets you check the return from calling C<< $event->$METHOD >> on your
event object. C<$EXPECT> should be the value you expect to be returned. You may
provide scalars, hashrefs, arrayrefs, or L<Test::Stream::DeepCheck::Check>
instances as the C<$EXPECT> value.

=item event_field $KEY => $VALUE

This lets you check the value of any key in the event hashref. C<$VALUE> can be
a scalar, arrayref, hashref or L<Test::Stream::DeepCheck::Check> instance.

=back

=head2 DEBUG CHECKS

These all verify data in the L<Test::Stream::DebugInfo> attached to the events.

=over 4

=item event_line $LINE

Check the line number that any failures will be reported to.

=item event_file $FILE

Check the file name that any failures will be reported to.

=item event_package $PACKAGE

Check the package name that any failures will be reported to.

=item event_sub $SUBNAME

Check the subname that any failures will be reported to.

=item event_trace $DEBUG_TRACE

Check the 'at FILE line LINE' string that will be used in the event of errors.

=item event_todo $TODO_REASON

Check the TODO status. This will either be undef, or the todo string.

=item event_skip $SKIP_REASON

Check the SKIP status. This will either be undef, or the skip string.

=back

=head2 MANIPULATING THE EVENT LIST

=over 4

=item end_events()

Use this to say that there should be no remaining events in the array.

=item @events = filter_events { grep { ... } @_ }

Use this to remove items from the event list. This can be used for example to
strip out Diag and leave only Ok events.

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
