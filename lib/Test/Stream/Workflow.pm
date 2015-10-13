package Test::Stream::Workflow;
use strict;
use warnings;

use Scalar::Util qw/reftype blessed/;
use Carp qw/confess croak/;

use Test::Stream::Sync;

use Test::Stream::Workflow::Meta;
use Test::Stream::Workflow::Unit;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/try set_sub_name CAN_SET_SUB_NAME sub_info/;

use Test::Stream::Exporter;
exports qw{
    workflow_build
    workflow_current
    workflow_meta
    workflow_runner
    workflow_runner_args
    workflow_var
    workflow_run
    new_proto_unit
    group_builder
    gen_unit_builder
    push_workflow_build
    pop_workflow_build
    push_workflow_vars
    pop_workflow_vars
    has_workflow_vars
};

export import => sub {
    my $class = shift;
    my ($pkg, $file, $line) = caller;

    Test::Stream::Exporter::export_from($class, $pkg, \@_);

    # This is a no-op if it has already been done.
    Test::Stream::Workflow::Meta->build($pkg, $file, $line, 'EOF');
};

export unimport => sub {
    my $caller = caller;
    my $meta = Test::Stream::Workflow::Meta->get($caller);
    $meta->set_autorun(0);
};
no Test::Stream::Exporter;

my $PKG = __PACKAGE__;
my %ALLOWED_STASHES = map {$_ => 1} qw{
    primary
    modify
    buildup
    teardown
    buildup+teardown
};

my @BUILD;
my @VARS;

sub workflow_current     { _current(caller) }
sub workflow_meta        { Test::Stream::Workflow::Meta->get(scalar caller) }
sub workflow_run         { Test::Stream::Workflow::Meta->get(scalar caller)->run(@_) }
sub workflow_runner      { Test::Stream::Workflow::Meta->get(scalar caller)->set_runner(@_) }
sub workflow_runner_args { Test::Stream::Workflow::Meta->get(scalar caller)->set_runner_args(@_) }

sub workflow_build { @BUILD ? $BUILD[-1] : undef }
sub push_workflow_build { push @BUILD => $_[0] || die "Nothing to push"; $_[0] }

sub pop_workflow_build {
    my ($should_be) = @_;

    croak "Build stack mismatch"
        unless @BUILD && $should_be && $BUILD[-1] == $should_be;

    pop @BUILD;
}

sub has_workflow_vars { scalar @VARS }
sub push_workflow_vars {
    my $vars = shift || {};
    push @VARS => $vars;
    $vars;
}

sub pop_workflow_vars {
    my ($should_be) = @_;

    croak "Vars stack mismatch!"
        unless @VARS && $should_be && $VARS[-1] == $should_be;

    my $it = pop @VARS;
    %$it = ();
    return;
}

sub workflow_var {
    confess "No VARS! workflow_var() should only be called inside a unit sub"
        unless @VARS;

    my $vars = $VARS[-1];

    my $name = shift;
    if (@_) {
        if (ref $_[0] && reftype($_[0]) eq 'CODE') {
            $vars->{$name} = $_[0]->()
                unless defined $vars->{$name};
        }
        else {
            ($vars->{$name}) = @_;
        }
    }
    return $vars->{$name};
};

sub _current {
    my ($caller) = @_;

    return $BUILD[-1] if @BUILD;
    my $spec_meta = Test::Stream::Workflow::Meta->get($caller) || return;
    return $spec_meta->unit;
}

sub die_at_caller {
    my ($caller, $msg) = @_;
    die "$msg at $caller->[1] line $caller->[2].\n";
}

sub new_proto_unit {
    my %params = @_;
    $params{level} = 1 unless defined $params{level};
    my $caller = $params{caller} || [caller($params{level})];
    my $args = $params{args};
    my $subname = $params{subname};

    unless ($subname) {
        $subname = $caller->[3];
        $subname =~ s/^.*:://g;
    }

    my ($name, $code, $meta, @lines);
    for my $item (@$args) {
        if (my $type = reftype($item)) {
            if ($type eq 'CODE') {
                die_at_caller $caller => "$subname() only accepts 1 coderef argument per call"
                    if $code;

                $code = $item;
            }
            elsif ($type eq 'HASH') {
                die_at_caller $caller => "$subname() only accepts 1 meta-hash argument per call"
                    if $meta;

                $meta = $item;
            }
            else {
                die_at_caller $caller => "Unknown argument to $subname: $item";
            }
        }
        elsif ($item =~ m/^\d+$/) {
            die_at_caller $caller => "$subname() only accepts 2 line number arguments per call (got: " . join(', ', @lines, $item) . ")"
                if @lines >= 2;

            push @lines => $item;
        }
        else {
            die_at_caller $caller => "$subname() only accepts 1 name argument per call (got: '$name', '$item')"
                if $name;

            $name = $item;
        }
    }

    die_at_caller $caller => "$subname() requires a name argument (non-numeric string)"
        unless $name;
    die_at_caller $caller => "$subname() requires a code reference"
        unless $code;

    my $info = sub_info($code, @lines);
    set_sub_name("$caller->[0]\::$name", $code) if CAN_SET_SUB_NAME && $info->{name} =~ m/__ANON__$/;

    my $unit = Test::Stream::Workflow::Unit->new(
        name       => $name,
        meta       => $meta,
        package    => $caller->[0],
        file       => $info->{file},
        start_line => $info->{start_line} || $caller->[2],
        end_line   => $info->{end_line}   || $caller->[2],

        $params{set_primary} ? (primary => $code) : (),

        $params{unit} ? (%{$params{unit}}) : (),
    );

    return ($unit, $code, $caller);
}

sub group_builder {
    my ($unit, $code, $caller) = new_proto_unit(
        args => \@_,
        unit => { type => 'group' },
    );

    push_workflow_build($unit);
    my ($ok, $err) = try {
        $code->($unit);
        1; # To force the previous statement to be in void context
    };
    pop_workflow_build($unit);
    die $err unless $ok;

    $unit->do_post;
    $unit->adjust_lines();

    return $unit if defined wantarray;

    my $current = _current($caller->[0])
        or confess "Could not find the current build!";

    $current->add_primary($unit);
}

sub _unit_builder_callback_simple {
    my ($current, $unit, @stashes) = @_;
    $current->$_($unit) for map {"add_$_"} @stashes;
}

sub _unit_builder_callback_modifiers {
    my ($current, $unit, @stashes) = @_;
    $current->add_post(sub {
        my $modify = $current->modify || return;
        for my $mod (@$modify) {
            $mod->$_($unit) for map {"add_$_"} @stashes;
        }
    });
}

sub _unit_builder_callback_primaries {
    my ($current, $unit, @stashes) = @_;

    # Get the stash, we will be using it just like any plugin might
    my $stash = $current->stash;

    # If we do not have data in the stash yet then we need to do some preliminary setup
    unless($stash->{$PKG}) {
        # Add our hash to the stash
        $stash->{$PKG} = {};

        # Add the post-callback, do it once here, we don't want to add
        # duplicate callbacks
        $current->add_post(sub {
            my $stuff = delete $stash->{$PKG};

            my $modify   = $stuff->{modify};
            my $buildup  = $stuff->{buildup};
            my $primary  = $stuff->{primary};
            my $teardown = $stuff->{teardown};

            my @search = ($current);
            while (my $it = shift @search) {
                if ($it->type && $it->type eq 'group') {
                    my $prim = $it->primary or next;
                    push @search => @$prim;
                    next;
                }

                unshift @{$it->{modify}}   => @$modify   if $modify;
                unshift @{$it->{buildup}}  => @$buildup  if $buildup;
                push    @{$it->{primary}}  => @$primary  if $primary;
                push    @{$it->{teardown}} => @$teardown if $teardown;
            }
        });
    }

    # Add the unit to the plugin stash for each unit stash (these names are not
    # ideal...) The data will be used by the post-callback that has already been added
    push @{$stash->{$PKG}->{$_}} => $unit for @stashes;
}

sub gen_unit_builder {
    my %params = @_;
    my $name = $params{name};
    my $callback = $params{callback} || croak "'callback' is a required argument";
    my $stashes = $params{stashes} || croak "'stashes' is a required argument";

    my $reftype = reftype($callback) || "";
    my $cb_sub = $reftype eq 'CODE' ? $callback : $PKG->can("_unit_builder_callback_$callback");
    croak "'$callback' is not a valid callback"
        unless $cb_sub;

    $reftype = reftype($stashes) || "";
    croak "'stashes' must be an array reference (got: $stashes)"
        unless $reftype eq 'ARRAY';

    my $wrap = @$stashes > 1 ? 1 : 0;
    my $check = join '+', sort @$stashes;
    croak "'$check' is not a valid stash"
        unless $ALLOWED_STASHES{$check};

    return sub {
        my ($unit, $code, $caller) = new_proto_unit(
            set_primary => 1,
            args        => [@_],
            unit        => {type => 'single', wrap => $wrap},
            name        => $name,
        );

        my $subname = $name || $caller->[3];

        confess "$subname must only be called in a void context"
            if defined wantarray;

        my $current = _current($caller->[0])
            or confess "Could not find the current build!";

        $cb_sub->($current, $unit, @$stashes);
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Workflow - Interface for writing 'workflow' tools such as RSPEC
implementations that all play nicely together.

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

This module intends to do for 'workflow' test tools what Test::Builder and
Test::Stream do for general test tools. The problem with workflow tools is that
most do not play well together. This module is a very generic/abstract look at
workflows that allows tools to be built that accomplish their workflows, but in
a way that plays well with others.

=head1 SYNOPSIS

    package My::Workflow::Tool;
    use Test::Stream::Workflow qw/gen_unit_builder/;

    use Test::Stream::Exporter;

    # Create a wrapping tool
    export my_wrapper => gen_unit_builder('simple' => qw/buildup teardown/);

    no Test::Stream::Exporter;

To use it:

    use My::Workflow::Tool qw/my_wrapper/;

    my_wrapper foo => sub {
        my $inner = shift;
        ...
        $inner->();
        ...
    };


=head1 IMPORTANT CONCEPTS

A workflow is a way of defining tests with scaffolding. Essentially you are
seperating your assertions and your setup/teardown/management code. This
results in a separation of concerns that can produce more maintainable tests.
In addition each component of a workflow can be re-usable and/or inheritable.

=head2 UNITS

Units are the small composable parts of a workflow. You can think of a unit as
a named function that does some work. What separates a unit from a regular
function is that it can have other units attashed to it in various ways. A unit
can also be a 'group' unit, which means it contains other units as its primary
work.

See L<Test::Stream::Workflow::Unit>.

=head2 PACKAGE UNIT

The package unit is the root 'group' unit for your test package. All other test
units get put into the main package unit.

See L<Test::Stream::Workflow::Meta> where the primary unit is stored.

=head2 BUILDS

Units are generally defined using a DSL (Domain Specific Language). In this DSL
you declare a unit, which gets added as the current build, then run code which
modifies that build to turn it into the unit you need.

=head2 BUILD STACK

Builds can be defined within one another, as such the 'current' build is
whatever build is on top of the build stack, which is a private array. There
are low level functions exposed to give you control over the stack if you need
it, but in general you should use a higher level tool.

=head2 TASK

A task is a composition of units to be run. The runner will compile you units
into task form, then run the compiled tasks.

=head2 VAR STASH

There is a var stash. The var stash is a stack of hashes. Every time a task is
run a new hash is pushed onto the stack. When a task is complete the hash is
popped and cleared. Workflow tools may use this hash to store/define variables
that will go away when the current task is complete.

=head1 EXPORTS

All exports are optional, you must request the ones you want.

=head2 BUILD STACK

=over 4

=item $unit = workflow_build()

Get the unit at the top of the build stack, if any.

=item $unit = workflow_current()

Get the unit at the top of the build stack, if there is none then return the
root unit for the package the function is called from.

=item push_workflow_build($unit)

Push a unit onto the build stack.

=item pop_workflow_build($unit)

Pop a unit from the build stack. You must provide the C<$unit> you expect to
pop, and it must match the one at the top of the stack.

=back

=head2 VAR STASH

=over 4

=item $val = workflow_var($name)

=item $val = workflow_var($name, $val)

=item $val = workflow_var($name, \&default)

This function will get/set a variable in the var stash. If only a name is
provided then it will return the current value, or undef. If you provide a
value as the second argument then the value will be set.

A coderef can be passed in as the second argument. If a coderef is used it will
be considered a default generator. If the variable name already has a value
then that value will be kept and returned. If the variable has not been set
then the coderef will be run and the value it returns will be stored and
returned.

=item $hr = push_workflow_vars()

=item push_workflow_vars($hr)

You can manually push a new hashref to the top of the vars stack. If you do
this you need to be sure to pop it before anything else tries to pop any hash
below yours in the stack. You can provide a hashref to push, or it will create
a new one for you.

=item pop_workflow_vars($hr)

This will let you manually pop the workflow vars stack. You must provide a
reference to the item you think is at the top of the stack (the one you want to
pop). If something else is on top of the stack then an exception will be
thrown.

=item $bool = has_workflow_vars()

Check if there is a workflow vars hash on the stack. This will return false if
there is nothing on the stack. Currently this returns the number of items in
the stack, but that may change so do not depend on that behavior.

=back

=head2 META DATA

=over 4

=item $meta = workflow_meta()

Get the L<Test::Stream::Workflow::Meta> object associated with the current
package.

=item workflow_runner($runner)

Set the runner to use. The runner can be a package name, or a blessed object.
Whichever you provide, it must have a 'run' method. The run method will be
called directly on what you provide, that is if you provide a package name then
it will call C<< $package->run() >> C<new()> will not be called for you.

=item workflow_runner_args(\@args)

Arguments that should be passed to the C<run()> method of your runner.

=item workflow_run()

Run the workflow now.

=back

=head2 CREATING UNITS

=over 4

=item $unit = group_builder($name, \%params, sub { ... })

=item $unit = group_builder($name, sub { ... })

=item group_builder($name, \%params, sub { ... })

=item group_builder($name, sub { ... })

The group builder will create a new unit with the given name and parameters.
The new unit will be placed onto the build stack, and the code reference you
provide will be run. Once the code reference returns the unit will be removed
from the build stack. If called in void context the unit will be added to the
next unit on the build stack, or to the package root unit. If called in any
other context the unit will be returned.

=item $sub = gen_unit_builder($callback, @stashes)

This will return a coderef that accepts the typical C<$name>, optional
C<\%params>, and C<\&code> arguments. The code returned will construct your
unit for you, and then insert it into the specified stashes of the current
build whenever it is called. Typically you will only specify one stash, but you
may combine C<buildup> and C<teardown> if the builder you are creating is
supposed to wrap other units.

B<Stashes:>

=over 4

=item primary

A primary action.

=item modify

Something to modify the primary actions.

=item buildup

Something to run before the primary actions.

=item teardown

Something to run after the primary actions.

=back

=item ($unit, $code, $caller) = new_proto_unit(\%params)

=over 4

=item level => 1

=item caller => [caller($level)]

=item args => [$name, \%params, \&code]

=item args => [$name, \&code]

=item set_primary => $bool

=item unit => \%attributes

This is used under the hood by C<gen_unit_builder()>. This will parse the 2 or
3 typical input arguments, verify them, and return a new
L<Test::Stream::Workflow::Unit>, the coderef that was passed in, and a caller
arrayref.

If you use this it is your job to put the unit where it should be. Normally
C<gen_unit_builder> and C<group_builder> are all you should need.

=back

=back

=head1 SEE ALSO

=over 4

=item Test::Stream::Plugin::Spec

L<Test::Stream::Plugin::Spec> is an implementation of RSPEC using this library.

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

