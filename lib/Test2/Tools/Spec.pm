package Test2::Tools::Spec;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/weaken/;

use Test2::Workflow qw{
    group_builder gen_unit_builder
    tool_import tool_unimport
};

use base 'Exporter';
our @EXPORT = qw{
    describe cases
    before_all after_all around_all

    tests it mini
    before_each after_each around_each

    case
    before_case after_case around_case

    async  iso
    masync miso
};

BEGIN {
    *import   = \&tool_import;
    *unimport = \&tool_unimport;

    *describe = \&group_builder;
    *cases    = \&group_builder;

    *tests       = gen_unit_builder(name => 'tests',       callback => 'simple',    stashes => ['primary']);
    *it          = gen_unit_builder(name => 'it',          callback => 'simple',    stashes => ['primary']);
    *case        = gen_unit_builder(name => 'case',        callback => 'simple',    stashes => ['modify']);
    *before_all  = gen_unit_builder(name => 'before_all',  callback => 'simple',    stashes => ['buildup']);
    *after_all   = gen_unit_builder(name => 'after_all',   callback => 'simple',    stashes => ['teardown']);
    *around_all  = gen_unit_builder(name => 'around_all',  callback => 'simple',    stashes => ['buildup', 'teardown']);
    *before_case = gen_unit_builder(name => 'before_case', callback => 'modifiers', stashes => ['buildup']);
    *after_case  = gen_unit_builder(name => 'after_case',  callback => 'modifiers', stashes => ['teardown']);
    *around_case = gen_unit_builder(name => 'around_case', callback => 'modifiers', stashes => ['buildup', 'teardown']);
    *before_each = gen_unit_builder(name => 'before_each', callback => 'primaries', stashes => ['buildup']);
    *after_each  = gen_unit_builder(name => 'after_each',  callback => 'primaries', stashes => ['teardown']);
    *around_each = gen_unit_builder(name => 'around_each', callback => 'primaries', stashes => ['buildup', 'teardown']);

    *mini = gen_unit_builder(name => 'mini', callback => 'simple', stashes => ['primary'], meta => { mini => 1 });

    *iso    = gen_unit_builder(name => 'iso',    callback => 'simple', stashes => ['primary'], meta => {iso   => 1});
    *async  = gen_unit_builder(name => 'async',  callback => 'simple', stashes => ['primary'], meta => {async => 1});
    *miso   = gen_unit_builder(name => 'miso',   callback => 'simple', stashes => ['primary'], meta => {iso   => 1, mini => 1});
    *masync = gen_unit_builder(name => 'masync', callback => 'simple', stashes => ['primary'], meta => {async => 1, mini => 1});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Tools::Spec - SPEC testing tools

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

Tools for writing SPEC style tests.

=head1 SYNOPSIS

    use Test2::Bundle::Extended;
    use Test2::Tools::Spec;

    describe fruit_shipment => sub {
        my $crates;
        before_all unload_crates => sub { $crates = get_crates() };
        after_all deliver_crates => sub { deliver($crates) };

        my $fruit;
        for my $f ($crates->types) { # 'pear' and 'apple'
            case $f => sub { $fruit = $f };
        }

        my $crate;
        before_each open_crate => sub { $crate = $crates->open_first($fruit) };
        after_each close_crate => sub { $crates->store($crate) };

        tests squishability => sub {
            my $sample = $crate->grab();
            ok($sample->squishability > 5, "squish rating is greater than 5");
            ok($sample->squishability < 10, "squish rating is less than 10");
        };

        tests flavor => sub {
            my $sample = $crate->grab();
            ok($sample->is_tasty, "sample is tasty");
            ok(!$sample->is_sour, "sample is not sour");
        };

        tests ripeness => sub {
            my $sample1 = $crate->grab();
            my $sample2 = $crate->grab();

            my $overripe  = grep { $_->is_overripe }  $sample1, $sample2;
            my $underripe = grep { $_->is_underripe } $sample1, $sample2;

            ok($overripe  < 2, "at least 1 sample is not overripe");
            ok($underripe < 2, "at least 1 sample is not underripe");
        };
    };

    done_testing;

In this sample we are describing a fruit shipment. Before anything else we
unload the crates. Next we handle 2 types of fruit, a crate of pears and a
crate of apples. For each create we need to run tests on squishability, flavor,
and ripeness. In order to run these tests the creates need to be opened, when
the tests are done the crates need to be closed again.

We use the before_all and after_all to specify the first and last tasks to be
run, each one will run exactly once. The 3 sets of tests will be run once per
fruit type, we have cases for pears and apples, so in total there will be 6
sets of tests run, 3 per fruit type. Opening and closing the crate is something
we need to do for each test block, so we use before_each and after_each.

Each test block needs unique samples, so the sample is aquired within the test.
We do not use a before_each as some tests require different numbers of samples.

=head1 IMPORT OPTIONS

    use Test2::Tools::Spec -opt => 'val', qw/tests describe .../;

Any argument prefixed with a '-' is considered an option, it and the following
argument will be used as arguments to the runner construction (with '-'
stripped off). All arguments without the '-' prefix will be considered imports.

=over 4

=item -verbose => $BOOL

Turns on some extra verbosity in debug messages.

=item -subtests => $BOOL

Normally all spec units are run as subtests. This can be used to turn off the
behavior by setting it to C<0>. B<Note:> L<Test2::Workflow::Runner::Isolate>
and subclasses currently ignore this flag.

=item -rand => $BOOL

Normally spec units are run in random order. This can be used to turn that
behavior off by setting it to C<0>.

=item -max => $INT

Maximum number of async units to run at a time, default is 3. When the
C<T2_WORKFLOW_ASYNC> environment variable is also set, the lowest value will be
used.

This is only effective when an isolating runner is used.

=item -no_fork => $BOOL

Specify that isolating runners should NOT use forking for isolation purposes.

This is only effective when an isolating runner is used.

=item -no_threads => $BOOL

Specify that isolating runners should NOT use threads for isolation purposes.

This is only effective when an isolating runner is used.

=back

=head1 EXPORTS

All exports have the exact same syntax, there are 2 forms:

    FUNCTION($NAME, \&CODE);
    FUNCTION($NAME, \%PARAMS, \&CODE);

Both can also be used in a style that is more pleasingto the eye:

    FUNCTION $NAME => sub { ... };
    FUNCTION $NAME => {...}, sub { ... }

The name and codeblock are required. Optionally you can provide a hashref
of parameters between the name and coderef with parameters. Valid parameters
depends on what runner is used, but the parameters supported by default are:

B<Note:> The default runner is L<Test2::Workflow::Runner>.

=over 4

=item todo => 'reason'

This will mark the entire block as todo with the given reason. This parameter
is inherited by nested blocks.

=item skip => 'reason'

This will skip the entire block, it will generate a single 'Ok' event with the
skip reason set.

=item mini => $bool

This tells the workflow system that the specified block is not significant
enough to need its own subtest or final 'ok'. This will basically cause all its
output to be inlined into the parent subtest. Use this if you have a nested
subtest with only 1 result, or where the additional subtest indentation adds
noise instead of helping.

This is completely aesthetic, it has no effect on if your tests will pass or
fail. This is here for humans, not machines.

=item async => $bool

Test block can run concurrently with other tests in another process or thread.
This does not mean it will, just that it may be.

Using this option will upgrade the runner to an
L<Test2::Workflow::Runner::Isolate> subclass.

=item iso => $bool

Test block B<MUST> be run in an isolated process or thread.

Using this option will upgrade the runner to an
L<Test2::Workflow::Runner::Isolate> subclass.

=back

B<Note:> The tests you declare are deferred, that is they run after everything
else is done, typically when you call C<done_testing>.

=head2 TEST DECLARATIONS

Test declarations are used to declare blocks of tests. You can put pretty much
anything you want inside a test block, the only exceptions to this is that
other test blocks, groups, modifiers, etc, cannot be specified inside the test
block.

If a test block does not produce any events then it will be considered an
error. Test blocks are usually run as subtests.

=over 4

=item tests $name => sub { ... }

=item it $name => sub { ... }

=item tests $name => \%params, sub { ... }

=item it $name => \%params, sub { ... }

C<tests()> and C<it()> are both aliases to the same function. The name
C<tests()> is present as the authors preference. C<it()> is present to reflect
the name used in RSPEC for the Ruby programming language.

B<Note:> The subs get no arguments, and their return is ignored.

=item mini $name => sub { ... }

=item mini $name => \%params, sub { ... }

Same as C<tests> and C<it> except that C<< mini => 1 >> is added to
C<\%params>.

=item async $name => sub { ... }

=item async $name => \%param, sub { ... }

Shortcut, adds the C<< async => 1 >> parameter.

=item iso $name => sub { ... }

=item iso $name => \%params, sub { ... }

Shortcut, adds the C<< iso => 1 >> parameter.

=item masync $name => sub { ... }

=item masync $name => \%params, sub { ... }

Shortcut, adds the C<< async => 1, mini => 1 >> parameters.

=item miso $name => sub { ... }

=item miso $name => \%params, sub { ... }

Shortcut, adds the C<< iso => 1, mini => 1 >> parameters.

=back

=head2 TEST SETUP AND TEARDOWN

These blocks attach themselves to test blocks. The setup/teardown will run once
for each test block. These are all inherited by test blocks declared in nested
groups.

=over 4

=item before_each $name => sub { ... }

Declare a setup that will run before each test block is run. B<Note:> This will
run before any modifier.

B<Note:> The subs get no arguments, and their return is ignored.

=item after_each $name => sub { ... }

Declare a teardown that will run after each test block.

B<Note:> The subs get no arguments, and their return is ignored.

=item around_each $name => sub { ... }

Declare a setup+teardown that is wrapped around the test block. This is useful
if you want to localize a variable, or something similar.

    around_each foo => sub {
        my $inner = shift;

        local %ENV;

        # You need to call the 'inner' sub.
        $inner->();
    };

B<Note:> The subs get no arguments, and their return is ignored.

=back

=head2 TEST MODIFIERS

=over 4

=item case $name => sub { ... }

You can specify any number of cases that should be used. All test blocks are
run once per case. Cases are inherited by nested groups.

B<Note:> The subs get no arguments, and their return is ignored.

=back

=head3 TEST MODIFIER SETUP AND TEARDOWN

=over 4

=item before_case $name => sub { ... }

Code to be run just before a case is run.

B<Note:> The subs get no arguments, and their return is ignored.

=item after_case $name => sub { ... }

Code to be run just after a case is run (but before the test block).

B<Note:> The subs get no arguments, and their return is ignored.

=item around_case $name => sub { ... }

Code that wraps around the case.

    around_case foo => sub {
        my $inner = shift;

        local %ENV;

        # You need to call the 'inner' sub.
        $inner->();
    };

B<Note:> The subs get no arguments, and their return is ignored.

=back

=head2 TEST GROUPS

=over 4

=item describe $name => sub { ... }

=item cases $name => sub { ... }

C<describe()> and C<cases()> are both aliases to the same thing.

These can be used to create groups of test block along with setup/teardown
subs. The cases, setups, and teardowns will not effect test blocks outside the
group. All cases, setups, and teardown will be inherited by any nested group.

B<Note:> Group subs are run as they are encountered, unlike test blocks which
are run at the very end of the test script.

B<Note:> The subs get no arguments, and their return is ignored.

=back

=head2 GROUP MODIFIERS

=over 4

=item before_all $name => sub { ... }

Specify a setup that gets run once at the start of the test group.

B<Note:> The subs get no arguments, and their return is ignored.

=item after_all $name => sub { ... }

Specify a teardown that gets run once at the end of the test group.

B<Note:> The subs get no arguments, and their return is ignored.

=item around_all $name => sub { ... }

Specify a teardown that gets run once, around the test group.

    around_all foo => sub {
        my $inner = shift;

        local %ENV;

        # You need to call the 'inner' sub.
        $inner->();
    };

B<Note:> The subs get no arguments, and their return is ignored.

=back

=head1 NOTE ON RUN ORDER

Within a test group (the main package counts as a group) things run in this order:

=over 4

=item group blocks (describe, cases)

=item END OF SCRIPT (done_testing called)

=item before_all + around_all starts

=over 4

=item before_each + around_each starts

=over 4

=item before_case + around_case starts

=over 4

=item case

=back

=item after_case + around_case stops

=item tests/it

=back

=item after_each + around_each stops

=back

=item after_all + around_all stops

=back

=head1 SOURCE

The source code repository for Test2-Workflow can be found at
F<http://github.com/Test-More/Test2-Workflow/>.

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
