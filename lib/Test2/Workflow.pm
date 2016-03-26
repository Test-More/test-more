package Test2::Workflow;
use strict;
use warnings;

our $VERSION = "0.000007";

our @EXPORT_OK = qw/parse_args current_build all_builds build root_build init_root/;
use base 'Exporter';

use Test2::Workflow::Build;
use Test2::Workflow::Task::Group;
use Test2::API qw/intercept/;
use Scalar::Util qw/blessed/;

sub parse_args {
    my %input = @_;
    my $args = delete $input{args};
    my %out;
    my %props;

    my $caller = $out{frame} = $input{caller} || caller(defined $input{level} ? $input{level} : 1);

    for my $arg (@$args) {
        if (my $r = ref($arg)) {
            if ($r eq 'HASH') {
                %props = (%props, %$arg);
            }
            elsif ($r eq 'CODE') {
                $out{code} = $arg
            }
            else {
                die "Not sure what to do with $arg at $caller->[1] line $caller->[2].\n";
            }
            next;
        }

        if ($arg =~ m/^\d+$/) {
            push @{$out{lines}} => $arg;
            next;
        }

        die "Name is already set to '$out{name}', cannot set to '$arg', did you specify multiple names at $caller->[1] line $caller->[2].\n"
            if $out{name};

        $out{name} = $arg;
    }

    die "a name must be provided, and must be truthy at $caller->[1] line $caller->[2].\n"
        unless $out{name};

    die "a codeblock must be provided at $caller->[1] line $caller->[2].\n"
        unless $out{code};

    return { %props, %out };
}

{
    my %ROOT_BUILDS;
    my @BUILD_STACK;

    sub root_build    { $ROOT_BUILDS{$_[0]} }
    sub current_build { @BUILD_STACK ? $BUILD_STACK[-1] : undef }
    sub all_builds    { @BUILD_STACK }

    sub init_root {
        my ($pkg, %args) = @_;
        $ROOT_BUILDS{$pkg} ||= Test2::Workflow::Build->new(
            name    => $pkg,
            flat    => 1,
            iso     => 0,
            async   => 0,
            is_root => 1,
            %args,
        );

        return $ROOT_BUILDS{$pkg};
    }

    sub build {
        my %params = @_;
        my $args = parse_args(%params);

        my $build = Test2::Workflow::Build->new(%$args);

        return $build if $args->{skip};

        push @BUILD_STACK => $build;

        my ($ok, $err);
        my $events = intercept {
            my $todo = $args->{todo} ? Test2::Todo->new(reason => $args->{todo}) : undef;
            $ok = eval { $args->{code}->(); 1 };
            $err = $@;
            $todo->end if $todo;
        };

        # Clear the stash
        $build->{stash} = [];
        $build->set_events($events);

        pop @BUILD_STACK;

        unless($ok) {
            my $hub = Test2::API::test2_stack->top;
            my $count = @$events;
            my $list = $count
                ? "Overview of unseen events:\n" . join "" => map "    " . blessed($_) . " " . $_->trace->debug . "\n", @$events
                : "";
            die <<"            EOT";
Exception in build '$args->{name}' with $count unseen event(s).
$err
$list
            EOT
        }

        return $build;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Workflow - Interface for writing 'workflow' tools such as RSPEC
implementations that all play nicely together.

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

This module intends to do for 'workflow' test tools what Test::Builder and
Test2 do for general test tools. The problem with workflow tools is that
most do not play well together. This module is a very generic/abstract look at
workflows that allows tools to be built that accomplish their workflows, but in
a way that plays well with others.

=head1 SYNOPSIS

=head1 IMPORTANT CONCEPTS

A workflow is a way of defining tests with scaffolding. Essentially you are
seperating your assertions and your setup/teardown/management code. This
results in a separation of concerns that can produce more maintainable tests.
In addition each component of a workflow can be re-usable and/or inheritable.

=head1 EXPORTS

All exports are optional, you must request the ones you want.

=head1 SEE ALSO

=over 4

=item Test2::Tools::Spec

L<Test2::Tools::Spec> is an implementation of RSPEC using this library.

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

Copyright 2016 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut

