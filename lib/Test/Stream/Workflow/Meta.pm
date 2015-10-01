package Test::Stream::Workflow::Meta;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/blessed/;

use Test::Stream::Workflow::Unit;

use Test::Stream::HashBase(
    accessors => [qw/unit runner runner_args autorun/],
);

my %METAS;

sub init {
    my $self = shift;

    confess "unit is a required attribute"
        unless $self->{+UNIT};
}

sub build {
    my $class = shift;
    my ($pkg, $file, $start_line, $end_line) = @_;

    return $METAS{$pkg} if $METAS{$pkg};

    my $unit = Test::Stream::Workflow::Unit->new(
        name       => $pkg,
        package    => $pkg,
        file       => $file,
        start_line => $start_line,
        end_line   => $end_line,
        type       => 'group'
    );

    my $meta = $class->new(
        UNIT()    => $unit,
        AUTORUN() => 1,
    );

    $METAS{$pkg} = $meta;

    my $hub = Test::Stream::Sync->stack->top;
    $hub->follow_up(
        sub {
            return unless $METAS{$pkg};
            return unless $METAS{$pkg}->autorun;
            $METAS{$pkg}->run;
            # Make sure the build cannot be found after done_testing
            delete $METAS{$pkg}->{+UNIT};
        }
    );

    return $meta;
}

sub purge {
    my $it = shift;
    my $pkg = $_[0];

    $pkg ||= $it->{+UNIT}->package if blessed($it) && $it->{+UNIT};

    croak "You must specify a package to purge"
        unless $pkg;

    delete $METAS{$pkg};
}

sub get {
    my $class = shift;
    my ($pkg) = @_;
    return $METAS{$pkg};
}

sub run {
    my $self = shift;
    my $runner = $self->runner;
    unless ($runner) {
        require Test::Stream::Workflow::Runner;
        $runner = 'Test::Stream::Workflow::Runner';
    }

    $self->unit->do_post;

    $runner->run(
        unit => $self->unit,
        args => $self->runner_args || [],
        no_final => 1
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Workflow::Meta - Meta-data for tests using workflows

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

When a test package uses workflows it needs a place to hold the primary unit.
This meta-data holds the primary unit for test packages. It also takes care of
ensuring they get run at the correct times.

=head1 METHODS

=head2 CLASS METHODS

=over 4

=item $meta = $CLASS->build($pkg, $file, $start_line, $end_line)

Create a meta-instance for the specified package. If one already exists it will
return the existing one instead, ignoring all arguments other than C<$pkg>.

=item $meta = $CLASS->get($pkg)

Get the existing meta-instance for the specified package. This will return
C<undef> if none exists.

=item $meta = $CLASS->purge($pkg)

Delete the meta-instance for the specified package. The instance will be
returned, but will no longer be tied to the package.

=back

=head2 OBJECT METHODS

=over 4

=item $unit = $meta->unit

=item $meta->set_unit($unit)

Get/Set the associated unit (L<Test::Stream::Workflow::Unit>).

=item $runner = $meta->runner

=item $meta->set_runner($runner)

Get/Set the runner to use (L<Test::Stream::Workflow::Runner>).

=item $ar = $meta->runner_args

=item $meta->set_runner_args([...])

Get/Set the args arrayref to be passed to the runner.

=item $bool = $meta->autorun

=item $meta->set_autorun($bool)

Defaults to true. Set this to 0 to turn off automatic running of the workflow.

=item $meta->run()

Run the workflow.

=item $meta->purge()

Remove the meta object from the package it was created for.

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
