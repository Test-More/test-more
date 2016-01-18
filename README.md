# NAME

Test2::Workflow - Interface for writing 'workflow' tools such as RSPEC
implementations that all play nicely together.

# \*\*\* EXPERIMENTAL \*\*\*

This distribution is experimental, anything can change at any time!

# DESCRIPTION

This module intends to do for 'workflow' test tools what Test::Builder and
Test2 do for general test tools. The problem with workflow tools is that
most do not play well together. This module is a very generic/abstract look at
workflows that allows tools to be built that accomplish their workflows, but in
a way that plays well with others.

# SYNOPSIS

    package My::Workflow::Tool;
    use Test2::Workflow qw/gen_unit_builder/;

    our @EXPORT = qw/my_wrapper/;
    use base 'Exporter';

    # Create a wrapping tool
    *my_wrapper = gen_unit_builder('simple' => qw/buildup teardown/);

To use it:

    use My::Workflow::Tool qw/my_wrapper/;

    my_wrapper foo => sub {
        my $inner = shift;
        ...
        $inner->();
        ...
    };

# IMPORTANT CONCEPTS

A workflow is a way of defining tests with scaffolding. Essentially you are
seperating your assertions and your setup/teardown/management code. This
results in a separation of concerns that can produce more maintainable tests.
In addition each component of a workflow can be re-usable and/or inheritable.

## UNITS

Units are the small composable parts of a workflow. You can think of a unit as
a named function that does some work. What separates a unit from a regular
function is that it can have other units attashed to it in various ways. A unit
can also be a 'group' unit, which means it contains other units as its primary
work.

See [Test2::Workflow::Unit](https://metacpan.org/pod/Test2::Workflow::Unit).

## PACKAGE UNIT

The package unit is the root 'group' unit for your test package. All other test
units get put into the main package unit.

See [Test2::Workflow::Meta](https://metacpan.org/pod/Test2::Workflow::Meta) where the primary unit is stored.

## BUILDS

Units are generally defined using a DSL (Domain Specific Language). In this DSL
you declare a unit, which gets added as the current build, then run code which
modifies that build to turn it into the unit you need.

## BUILD STACK

Builds can be defined within one another, as such the 'current' build is
whatever build is on top of the build stack, which is a private array. There
are low level functions exposed to give you control over the stack if you need
it, but in general you should use a higher level tool.

## TASK

A task is a composition of units to be run. The runner will compile you units
into task form, then run the compiled tasks.

## VAR STASH

There is a var stash. The var stash is a stack of hashes. Every time a task is
run a new hash is pushed onto the stack. When a task is complete the hash is
popped and cleared. Workflow tools may use this hash to store/define variables
that will go away when the current task is complete.

# EXPORTS

All exports are optional, you must request the ones you want.

## BUILD STACK

- $unit = workflow\_build()

    Get the unit at the top of the build stack, if any.

- $unit = workflow\_current()

    Get the unit at the top of the build stack, if there is none then return the
    root unit for the package the function is called from.

- push\_workflow\_build($unit)

    Push a unit onto the build stack.

- pop\_workflow\_build($unit)

    Pop a unit from the build stack. You must provide the `$unit` you expect to
    pop, and it must match the one at the top of the stack.

## VAR STASH

- $val = workflow\_var($name)
- $val = workflow\_var($name, $val)
- $val = workflow\_var($name, \\&default)

    This function will get/set a variable in the var stash. If only a name is
    provided then it will return the current value, or undef. If you provide a
    value as the second argument then the value will be set.

    A coderef can be passed in as the second argument. If a coderef is used it will
    be considered a default generator. If the variable name already has a value
    then that value will be kept and returned. If the variable has not been set
    then the coderef will be run and the value it returns will be stored and
    returned.

- $hr = push\_workflow\_vars()
- push\_workflow\_vars($hr)

    You can manually push a new hashref to the top of the vars stack. If you do
    this you need to be sure to pop it before anything else tries to pop any hash
    below yours in the stack. You can provide a hashref to push, or it will create
    a new one for you.

- pop\_workflow\_vars($hr)

    This will let you manually pop the workflow vars stack. You must provide a
    reference to the item you think is at the top of the stack (the one you want to
    pop). If something else is on top of the stack then an exception will be
    thrown.

- $bool = has\_workflow\_vars()

    Check if there is a workflow vars hash on the stack. This will return false if
    there is nothing on the stack. Currently this returns the number of items in
    the stack, but that may change so do not depend on that behavior.

## META DATA

- $meta = workflow\_meta()

    Get the [Test2::Workflow::Meta](https://metacpan.org/pod/Test2::Workflow::Meta) object associated with the current
    package.

- workflow\_runner($runner)

    Set the runner to use. The runner can be a package name, or a blessed object.
    Whichever you provide, it must have a 'run' method. The run method will be
    called directly on what you provide, that is if you provide a package name then
    it will call `$package->run()` `new()` will not be called for you.

- workflow\_runner\_args(\\@args)

    Arguments that should be passed to the `run()` method of your runner.

- workflow\_run()

    Run the workflow now.

## CREATING UNITS

- $unit = group\_builder($name, \\%params, sub { ... })
- $unit = group\_builder($name, sub { ... })
- group\_builder($name, \\%params, sub { ... })
- group\_builder($name, sub { ... })

    The group builder will create a new unit with the given name and parameters.
    The new unit will be placed onto the build stack, and the code reference you
    provide will be run. Once the code reference returns the unit will be removed
    from the build stack. If called in void context the unit will be added to the
    next unit on the build stack, or to the package root unit. If called in any
    other context the unit will be returned.

- $sub = gen\_unit\_builder($callback, @stashes)

    This will return a coderef that accepts the typical `$name`, optional
    `\%params`, and `\&code` arguments. The code returned will construct your
    unit for you, and then insert it into the specified stashes of the current
    build whenever it is called. Typically you will only specify one stash, but you
    may combine `buildup` and `teardown` if the builder you are creating is
    supposed to wrap other units.

    **Stashes:**

    - primary

        A primary action.

    - modify

        Something to modify the primary actions.

    - buildup

        Something to run before the primary actions.

    - teardown

        Something to run after the primary actions.

- ($unit, $code, $caller) = new\_proto\_unit(\\%params)
    - level => 1
    - caller => \[caller($level)\]
    - args => \[$name, \\%params, \\&code\]
    - args => \[$name, \\&code\]
    - set\_primary => $bool
    - unit => \\%attributes

        This is used under the hood by `gen_unit_builder()`. This will parse the 2 or
        3 typical input arguments, verify them, and return a new
        [Test2::Workflow::Unit](https://metacpan.org/pod/Test2::Workflow::Unit), the coderef that was passed in, and a caller
        arrayref.

        If you use this it is your job to put the unit where it should be. Normally
        `gen_unit_builder` and `group_builder` are all you should need.

# SEE ALSO

- Test2::Tools::Spec

    [Test2::Tools::Spec](https://metacpan.org/pod/Test2::Tools::Spec) is an implementation of RSPEC using this library.

# SOURCE

The source code repository for Test2-Workflow can be found at
`http://github.com/Test-More/Test2-Workflow/`.

# MAINTAINERS

- Chad Granum &lt;exodist@cpan.org>

# AUTHORS

- Chad Granum &lt;exodist@cpan.org>

# COPYRIGHT

Copyright 2015 Chad Granum &lt;exodist7@gmail.com>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See `http://dev.perl.org/licenses/`
