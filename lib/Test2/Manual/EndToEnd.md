# NAME

Test2::Manual::EndToEnd - Overview of Test2 from load to finish.

# DESCRIPTION

This is a high level overview of everything from loading Test2 through the end
of a test script.

# WHAT HAPPENS WHEN I LOAD THE API?

    use Test2::API qw/context/;

- A singleton instance of Test2::API::Instance is created.

    You have no access to this, it is an implementation detail.

- Several API functions are defined that use the singleton instance.

    You can import these functions, or use them directly.

- Then what?

    It waits...

    The API intentionally does as little as possible. At this point something can
    still change the formatter, load [Test2::IPC](https://metacpan.org/pod/Test2::IPC), or have other global effects
    that need to be done before the first [Test2::API::Context](https://metacpan.org/pod/Test2::API::Context) is created. Once
    the first [Test2::API::Context](https://metacpan.org/pod/Test2::API::Context) is created the API will finish initialization.

    See ["WHAT HAPPENS WHEN I AQUIRE A CONTEXT?"](#what-happens-when-i-aquire-a-context) for more information.

# WHAT HAPPENS WHEN I USE A TOOL?

This section covers the basic workflow all tools such as `ok()` must follow.

    sub ok($$) {
        my ($bool, $name) = @_;

        my $ctx = context();

        my $event = $ctx->send_event('Ok', pass => $bool, name => $name);

        ...

        $ctx->release;
        return $bool;
    }

    ok(1, "1 is true");

- A tool function is run.

        ok(1, "1 is true");

- The tool acquires a context object.

        my $ctx = context();

    See ["WHAT HAPPENS WHEN I AQUIRE A CONTEXT?"](#what-happens-when-i-aquire-a-context) for more information.

- The tool uses the context object to create, send, and return events.

    See ["WHAT HAPPEND WHEN I SEND AN EVENT?"](#what-happend-when-i-send-an-event) for more information.

        my $event = $ctx->send_event('Ok', pass => $bool, name => $name);

- When done the tool MUST release the context.

    See ["WHAT HAPPENS WHEN I RELEASE A CONTEXT?"](#what-happens-when-i-release-a-context) for more information.

        $ctx->release();

- The tool returns.

        return $bool;

# WHAT HAPPENS WHEN I ACQUIRE A CONTEXT?

    my $ctx = context();

These actions may not happen exactly in this order, but that is an
implementation detail. For the purposes of this document this order is used to
help the reader understand the flow.

- $!, $@, and $? are captured and preserved.

    Test2 makes a point to preserve the values of $!, $@, and $? such that the test
    tools do not modify these variables unexpectedly. They are captured first thing
    so that they can be restored later.

- The API state is changed to 'loaded'.

    The 'loaded' state means that test tools have already started running. This is
    important as some plugins need to take effect before any tests are run. This
    state change only happens the first time a context is acquired, and may trigger
    some hooks defined by plugins to run.

- The current hub is found.

    A context attaches itself to the current [Test2::Hub](https://metacpan.org/pod/Test2::Hub). If there is no current
    hub then the root hub will be initialized. This will also initialize the hub
    stack if necessary.

- Context acquire hooks fire.

    It is possible to create global, or hub-specific hooks that fire whenever a
    context is acquired, these hooks will fire now. These hooks fire even if there
    is an existing context.

- Any existing context is found.

    If the current hub already has a context then a clone of it will be used
    instead of a completely new context. This is important because it allows nested
    tools to inherit the context used by parent tools.

- Stack depth is measured.

    Test2 makes a point to catch mistakes in how the context is used. The stack
    depth is used to accomplish this. If there is an existing context the depth
    will be checked against the one found here. If the old context has the same
    stack depth, or a shallower one, it means a tool is misbehaving and did not
    clean up the context when it was done, in which case the old context will be
    cleaned up, and a warning issued.

- A new context is created (if no existing context was found)

    If there is no existing context, a new one will be created using the data
    collected so far.

- Context init hooks fire (if no existing context was found)

    If a new context was created, context-creation hooks will fire.

- $!, $@, and $? are restored.

    We make sure $!, $@, and $? are restored so that changes we made will not
    effect anything else.

- The context is returned.

    You have a shiney new context object, or a clone of the existing context.

# WHAT HAPPENS WHEN I SEND AN EVENT?

    my $event = $ctx->send_event('Ok', pass => $bool, name => $name);

- The Test2::Event::Ok module is loaded.

    The `send_event()` method will automatically load any Event package necessary.

- A new instance of Test2::Event::Ok is created.

    The event object is instantiated using the provided parameters.

- The event object is sent to the hub.

    The hub taks over from here.

- The hub runs the event through any filters.

    Filters are able to modify or remove events. Filters are run first, before the
    event can modify global test state.

- The global test state is updated to reflect the event.

    If the event effects test count then the count will be incremented. If the
    event causes failure then the failure count will be incremented. There are a
    couple other ways the global state can be effected as well.

- The event is sent to the formatter

    After the state is changed the hub will send the event to the formatter for
    rendering. This is where TAP is normally produced.

- The event is sent to all listeners.

    There can be any number of listeners that take action when events are
    processed, this happens now.

# WHAT HAPPENS WHEN I RELEASE A CONTEXT?

    $ctx->release;

- The current context clone is released.

    If your tool is nested inside another, then releasing will simply destroy the
    copy of the context, nothing else will happen.

- If this was the canonical context, it will actually release

    When a context is created it is considered 'canon'. Any context obtained by a
    nested tool will be considered a child context linked to the canonical one.
    Releasing child contexts does not do anything of note (but is still required).

- Release hooks are called

    Release hooks are the main motivation behind making the `release()` method,
    and making it a required action on the part of test tools. These are hooks that
    we can have called when a tool is complete. This is how plugins like
    [Test2::Plugin::DieOnFail](https://metacpan.org/pod/Test2::Plugin::DieOnFail) are implemented. If we simply had a destructor call
    the hooks then we would be unable to write this plugin as a `die` inside of a
    destructor is useless.

- The context is cleared

    The main context data is cleared allowing the next tool to create a new
    context. This is important as the next tool very likely has a new line number.

- $!, $@, and $? are restored

    When a Test2 tool is complete it will restore $@, $!, and $? to avoid action at
    a distance.

# WHAT HAPPENS WHEN I USE done\_testing()?

    done_testing();

- Any pending IPC events will be culled.

    If IPC is turned on, a final culling will take place.

- Follow-up hooks are run

    The follow-up hooks are a way to run actions when a hub is complete. This is
    useful for adding cleanup tasks, or final tests to the end of a test.

- The final plan even is generated and processed.

    The final plan event will be produced using the current test count as the
    number of tests planned.

- The current hub is finalized.

    This will mark the hub is complete, and will not allow new events to be
    processed.

# WHAT HAPPENS WHEN A TEST SCRIPT IS DONE?

Test2 has some behaviors it runs in an `END { ... }` block after tests are
done running. This end block does some final checks to warn you if something
went wrong. This end block also sets the exit value of the script.

- API Versions are checked.

    A warning will be produced if [Test::Builder](https://metacpan.org/pod/Test::Builder) is loaded, but has a different
    version compared to [Test2::API](https://metacpan.org/pod/Test2::API). This situation can happen if you downgrade
    to an older Test-Simple distribution, and is a bad situation.

- Any remaining context objects are cleaned up.

    If there are leftover context objects they will need to be cleaned up. A
    leftover context is never a good thing, and usually requires a warning. A
    leftover context could also be the result of an exception being thrown which
    terminates the script, [Test2](https://metacpan.org/pod/Test2) is fairly good at noticing this and not warning
    in these cases as the warning would simply be noise.

- Child processes are sent a 'waiting' event.

    If IPC is active, a waiting event is sent to all child processes.

- The script will wait for all child processes and/or threads to complete.

    This happens only when IPC is loaded, but Test::Builder is not. This behavior
    is useful, but would break compatability for legacy tests.

- The hub stack is cleaned u.p

    All hubs are finalized starting from the top. Leftover hubs are usually a bad
    thing, so a warning is produced if any are found.

- The root hub is finalized.

    This step is a no-op if `done_testing()` was used. If needed this will mark
    the root hub as finished.

- Exit callbacks are called.

    This is a chance for plugins to modify the final exit value of the script.

- The scripts exit value ($?) is set.

    If the test encountered any failures this will be set to a non-zero value. If
    possible this will be set to the number of failures, or 255 if the number is
    larger than 255 (the max value allowed).

- Broken moule diagnostics

    Test2 is aware of many modules which were broken by Test2's release. At this
    point the script will check if any known-broken modules were loaded, and warn
    you if they were.

    **Note:** This only happens if there were test failures. No broken module
    warnings are produced on a success.

# SEE ALSO

[Test2::Manual](https://metacpan.org/pod/Test2::Manual) - Primary index of the manual.

# SOURCE

The source code repository for Test2-Manual can be found at
`http://github.com/Test-More/Test2-Manual/`.

# MAINTAINERS

- Chad Granum <exodist@cpan.org>

# AUTHORS

- Chad Granum <exodist@cpan.org>

# COPYRIGHT

Copyright 2016 Chad Granum <exodist@cpan.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://dev.perl.org/licenses/`
