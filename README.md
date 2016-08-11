# NAME

Test2 - Framework for writing test tools that all work together.

# DESCRIPTION

Test2 is a new testing framework produced by forking [Test::Builder](https://metacpan.org/pod/Test::Builder),
completely refactoring it, adding many new features and capabilities.

# GETTING STARTED

If you are interested in writing tests using new tools then you should look at
[Test2::Suite](https://metacpan.org/pod/Test2::Suite). [Test::Suite](https://metacpan.org/pod/Test::Suite) is a separate cpan distribution that contains
many tools implemented on Test2.

If you are interested in writing new tools you should take a look at
[Test2::API](https://metacpan.org/pod/Test2::API) first.

# NAMESPACE LAYOUT

This describes the namespace layout for the Test2 ecosystem. Not all the
namespaces listed here are part of the Test2 distribution, some are implemented
in [Test2::Suite](https://metacpan.org/pod/Test2::Suite).

## Test2::Tools::

This namespace is for sets of tools. Modules in this namespace should export
tools like `ok()` and `is()`. Most things written for Test2 should go here.
Modules in this namespace **MUST NOT** export subs from other tools. See the
["Test2::Bundle::"](#test2-bundle) namespace if you want to do that.

## Test2::Plugin::

This namespace is for plugins. Plugins are modules that change or enhance the
behavior of Test2. An example of a plugin is a module that sets the encoding to
utf8 globally. Another example is a module that causes a bail-out event after
the first test failure.

## Test2::Bundle::

This namespace is for bundles of tools and plugins. Loading one of these may
load multiple tools and plugins. Modules in this namespace should not implement
tools directly. In general modules in this namespace should load tools and
plugins, then re-export things into the consumers namespace.

## Test2::Require::

This namespace is for modules that cause a test to be skipped when conditions
do not allow it to run. Examples would be modules that skip the test on older
perls, or when non-essential modules have not been installed.

## Test2::Formatter::

Formatters live under this namespace. [Test2::Formatter::TAP](https://metacpan.org/pod/Test2::Formatter::TAP) is the only
formatter currently. It is acceptable for third party distributions to create
new formatters under this namespace.

## Test2::Event::

Events live under this namespace. It is considered acceptable for third party
distributions to add new event types in this namespace.

## Test2::Hub::

Hub subclasses (and some hub utility objects) live under this namespace. It is
perfectly reasonable for third party distributions to add new hub subclasses in
this namespace.

## Test2::IPC::

The IPC subsystem lives in this namespace. There are not many good reasons to
add anything to this namespace, with exception of IPC drivers.

### Test2::IPC::Driver::

IPC drivers live in this namespace. It is fine to create new IPC drivers and to
put them in this namespace.

## Test2::Util::

This namespace is for general utilities used by testing tools. Please be
considerate when adding new modules to this namespace.

## Test2::API::

This is for Test2 API and related packages.

## Test2::

The Test2:: namespace is intended for extensions and frameworks. Tools,
Plugins, etc should not go directly into this namespace. However extensions
that are used to build tools and plugins may go here.

In short: If the module exports anything that should be run directly by a test
script it should probably NOT go directly into `Test2::XXX`.

# SEE ALSO

[Test2::API](https://metacpan.org/pod/Test2::API) - Primary API functions.

[Test2::API::Context](https://metacpan.org/pod/Test2::API::Context) - Detailed documentation of the context object.

[Test2::IPC](https://metacpan.org/pod/Test2::IPC) - The IPC system used for threading/fork support.

[Test2::Formatter](https://metacpan.org/pod/Test2::Formatter) - Formatters such as TAP live here.

[Test2::Event](https://metacpan.org/pod/Test2::Event) - Events live in this namespace.

[Test2::Hub](https://metacpan.org/pod/Test2::Hub) - All events eventually funnel through a hub. Custom hubs are how
`intercept()` and `run_subtest()` are implemented.

# CONTACTING US

Many Test2 developers and users lurk on [irc://irc.perl.org/#perl](irc://irc.perl.org/#perl). We also
have a slack team that can be joined by anyone with an `@cpan.org` email
address [https://perl-test2.slack.com/](https://perl-test2.slack.com/) If you do not have an `@cpan.org`
email you can ask for a slack invite by emailing Chad Granum
<exodist@cpan.org>.

# SOURCE

The source code repository for Test2 can be found at
`http://github.com/Test-More/test-more/`.

# MAINTAINERS

- Chad Granum <exodist@cpan.org>

# AUTHORS

- Chad Granum <exodist@cpan.org>

# COPYRIGHT

Copyright 2016 Chad Granum <exodist@cpan.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://dev.perl.org/licenses/`
