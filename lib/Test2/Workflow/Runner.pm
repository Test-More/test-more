package Test2::Workflow::Runner;
use strict;
use warnings;

use Test2::Util qw/try/;

use Test2::Workflow::Task();
use Test2::API qw/test2_stack/;
use List::Util qw/shuffle/;

use Test2::Util::HashBase qw/verbose subtests rand/;

sub init {
    my $self = shift;

    $self->{+RAND} = 1 unless exists $self->{+RAND};
}

sub instance {
    my $class = shift;
    my %args = @_;

    return $class->new(
        subtests => 1,
        %args,
    );
}

sub import {
    my $class  = shift;
    my $caller = caller;

    require Test2::Workflow::Meta;
    my $meta = Test2::Workflow::Meta->get($caller) or return;
    $meta->set_runner($class->instance(@_));
}

my %SUPPORTED = map {$_ => 1} qw/todo skip mini/;
sub supported_meta_keys { \%SUPPORTED }

sub verify_meta {
    my $class = shift;
    my ($unit) = @_;
    my $meta = $unit->meta or return;
    my $supported = $class->supported_meta_keys;
    my $ctx = $unit->context;
    for my $k (keys %$meta) {
        next if $supported->{$k};
        $ctx->alert("'$k' is not a recognised meta-key");
    }
}

sub run {
    my $self = shift;
    my %params = @_;
    my $unit     = $params{unit};
    my $args     = $params{args};
    my $no_final = $params{no_final};

    $self->verify_meta($unit);

    if ($self->{+RAND}) {
        my $p = $unit->primary;
        @$p = shuffle @$p if ref($p) eq 'ARRAY';
    }

    my $task = Test2::Workflow::Task->new(
        unit       => $unit,
        args       => $args,
        runner     => $self,
        no_final   => $no_final,
        no_subtest => !$self->subtests($unit),
    );

    my ($ok, $err) = try { $self->run_task($task) };
    test2_stack->top->cull();

    # Report exceptions
    unless($ok) {
        my $ctx = $unit->context;
        $ctx->ok(0, $unit->name, ["Caught Exception: $err"]);
    }

    return;
}

sub run_task {
    my $class = shift;
    my ($task) = @_;

    return $task->run();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Workflow::Runner - Simple runner for workflows.

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

This is a basic class for running workflows. This class is intended to be
subclasses for more fancy/feature rich workflows.

=head1 SYNOPSIS

=head2 SUBCLASS

    package My::Runner;
    use strict;
    use warnings;

    use parent 'Test2::Workflow::Runner';

    sub instance {
        my $class = shift;
        return $class->new(@_);
    }

    sub subtest {
        my $self = shift;
        my ($unit) = @_;
        ...
        return $bool
    }

    sub verify_meta {
        my $self = shift;
        my ($unit) = @_;
        my $meta = $unit->meta || return;
        warn "the 'foo' meta attribute is not supported" if $meta->{foo};
        ...
    }

    sub run_task {
        my $self = shift;
        my ($task) = @_;
        ...
        $task->run();
        ...
    }

=head2 USE SUBCLASS

    use Test2 qw/... Spec/;

    use My::Runner; # Sets the runner for the Spec plugin.

    ...

=head1 METHODS

=head2 CLASS METHODS

=over 4

=item $class->import()

=item $class->import(@instance_args)

The import method checks the calling class to see if it has an
L<Test2::Workflow::Meta> instance, if it does then it sets the runner.
The runner that is set is the result of calling
C<< $class->instance(@instance_args) >>. The instance_args are optional.

If there is no meta instance for the calling class then import is a no-op.

=item $bool = $class->subtests($unit)

This determines if the units should be run as subtest or flat. The base class
always returns true for this. This is a hook that allows you to override the
default behavior.

=item $runner = $class->instance()

=item $runner = $class->instance(@args)

This is a hook allowing you to construct an instance of your runner. The base
class simply returns the class name as it does not need to be instansiated. If
your runner needs to maintain state then this can return a blessed instance.

=back

=head2 CLASS AND/OR OBJECT METHODS

These are made to work on the class itself, but should also work just fine on a
blessed instance if your subclass needs to be instantiated.

=over 4

=item $runner->verify_meta($unit)

This method reads the C<< $unit->meta >> hash and warns about any unrecognised
keys. Your subclass should override this if it wants to add support for any
meta-keys.

=item $runner->run(unit => $unit, args => $arg)

=item $runner->run(unit => $unit, args => $arg, no_final => $bool)

Tell the runner to run a unit with the specified args. The args are optional.
The C<no_final> arg is optional, it should be used on support units that should
not produce final results (or be a subtest of their own).

=item $runner->run_task($task)

This simply calls C<< $task->run() >>. It is mainly here for subclasses to
override.

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
