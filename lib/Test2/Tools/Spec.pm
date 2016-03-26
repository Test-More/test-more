package Test2::Tools::Spec;
use strict;
use warnings;

use Carp qw/croak/;
use Test2::Workflow qw/parse_args build current_build root_build init_root/;

use Test2::Workflow::Runner();
use Test2::Workflow::Task::Action();
use Test2::Workflow::Task::Group();
use Test2::Tools::Mock();
use Importer();

use vars qw/@EXPORT @EXPORT_OK/;
push @EXPORT => qw{describe cases};
push @EXPORT_OK => qw{include_workflow include_workflows};

my %HANDLED;
sub import {
    my $class = shift;
    my @caller = caller(0);

    my %root_args;
    my %runner_args;
    my @import;
    while (my $arg = shift @_) {
        if ($arg =~ s/^-//) {
            my $val = shift @_;

            if (Test2::Workflow::Runner->can($arg)) {
                $runner_args{$arg} = $val;
            }
            elsif (Test2::Workflow::Task::Group->can($arg)) {
                $root_args{$arg} = $val;
            }
            elsif ($arg eq 'root_args') {
                %root_args = (%root_args, %$val);
            }
            elsif ($arg eq 'runner_args') {
                %runner_args = (%runner_args, %$val);
            }
            else {
                croak "Unrecognized arg: $arg";
            }
        }
        else {
            push @import => $arg;
        }
    }

    if ($HANDLED{$caller[0]}++) {
        croak "Package $caller[0] has already been initialized"
            if keys(%root_args) || keys(%runner_args);
    }
    else {
        my $root = init_root(
            $caller[0],
            frame => \@caller,
            code => sub { 1 },
            %root_args,
        );

        my $runner = Test2::Workflow::Runner->new(%runner_args);

        Test2::Tools::Mock->add_handler(
            $caller[0],
            sub {
                my %params = @_;
                my ($class, $caller, $builder, $args) = @params{qw/class caller builder args/};

                # Running
                if (@{$runner->stack}) {
                    $runner->add_mock($builder->());
                }
                else { # Not running
                    my $action = Test2::Workflow::Task::Action->new(
                        code     => sub { $runner->add_mock($builder->()) },
                        name     => "mock $class",
                        frame    => $caller,
                        scaffold => 1,
                    );

                    my $build = current_build() || $root;

                    $build->add_primary_setup($action);
                    $build->add_stash($builder->());
                }

                return 1;
            }
        );

        my $stack = Test2::API::test2_stack;
        $stack->top; # Insure we have a hub
        my ($hub) = Test2::API::test2_stack->all;
        $hub->follow_up(
            sub {
                return unless $root->populated;
                my $g = $root->compile;
                $runner->push_task($g);
                $runner->run;
            }
        );
    }

    Importer->import_into($class, $caller[0], @import);
}

{
    no warnings 'once';
    *cases             = \&describe;
    *include_workflows = \&include_workflow;
}

sub describe {
    my @caller = caller(0);
    my $build = build(args => \@_, caller => \@caller);

    return $build if defined wantarray;

    my $current = current_build() || root_build($caller[0])
        or croak "No current workflow build!";

    $current->add_primary($build);
}

sub include_workflow {
    my @caller = caller(0);

    my $build = current_build() || root_build(\$caller[0])
        or croak "No current workflow build!";

    for my $task (@_) {
        croak "include_workflow only accepts Test2::Workflow::Task objects, got: $task"
            unless $task->isa('Test2::Workflow::Task');

        $build->add_primary($task);
    }
}

# Generate a bunch of subs that only have minor differences between them.
BEGIN {
    @EXPORT = qw{
        tests it
        case
        before_all  around_all  after_all
        before_case around_case after_case
        before_each around_each after_each
    };

    @EXPORT_OK = qw{
        mini
        iso   miso
        async masync
    };

    my %stages = (
        case  => ['add_variant'],
        tests => ['add_primary'],
        it    => ['add_primary'],

        iso  => ['add_primary'],
        miso => ['add_primary'],

        async  => ['add_primary'],
        masync => ['add_primary'],

        mini => ['add_primary'],

        before_all => ['add_setup'],
        after_all  => ['add_teardown'],
        around_all => ['add_setup', 'add_teardown'],

        before_case => ['add_variant_setup'],
        after_case  => ['add_variant_teardown'],
        around_case => ['add_variant_setup', 'add_variant_teardown'],

        before_each => ['add_primary_setup'],
        after_each  => ['add_primary_teardown'],
        around_each => ['add_primary_setup', 'add_primary_teardown'],
    );

    my %props = (
        case  => [],
        tests => [],
        it    => [],

        iso  => [iso => 1],
        miso => [iso => 1, flat => 1],

        async  => [async => 1],
        masync => [async => 1, flat => 1],

        mini => [flat => 1],

        before_all => [scaffold => 1],
        after_all  => [scaffold => 1],
        around_all => [scaffold => 1, around => 1],

        before_case => [scaffold => 1],
        after_case  => [scaffold => 1],
        around_case => [scaffold => 1, around => 1],

        before_each => [scaffold => 1],
        after_each  => [scaffold => 1],
        around_each => [scaffold => 1, around => 1],
    );

    my $run = "";
    for my $func (@EXPORT, @EXPORT_OK) {
        $run .= <<"        EOT";
#line ${ \(__LINE__ + 1) } "${ \__FILE__ }"
sub $func {
    my \@caller = caller(0);
    my \$args = parse_args(args => \\\@_, caller => \\\@caller);
    my \$action = Test2::Workflow::Task::Action->new(\@{\$props{$func}}, %\$args);

    return \$action if defined wantarray;

    my \$build = current_build() || root_build(\$caller[0])
        or croak "No current workflow build!";

    \$build->\$_(\$action) for \@{\$stages{$func}};
}
        EOT
    }

    my ($ok, $err);
    {
        local $@;
        $ok = eval "$run\n1";
        $err = $@;
    }

    die $@ unless $ok;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

=head1 SYNOPSIS

=head1 EXPORTS

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

Copyright 2016 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut

