package Test2::Workflow;
use strict;
use warnings;

our @EXPORT_OK = qw/parse_args current_build all_builds build_group/;
use base 'Exporter';

use Test2::Workflow::Build;
use Test2::Workflow::Group;

sub parse_args {
    my %input = @_;
    my $args = delete $input{args};
    my %out;

    my $caller = $out{frame} = $input{caller} || caller(defined $input{level} ? $input{level} : 1);
    $out{lines} = [$caller->[2]];

    for my $arg (@$args) {
        if (my $r = ref($arg)) {
            if ($r eq 'HASH') {
                $out{props} = $arg;
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

        die "Name is already set to '$out{name}', cannto set to '$arg', did you specify multiple names at $caller->[1] line $caller->[2].\n"
            if $out{name};

        $out{name} = $arg;
    }

    die "a name must be provided, and must be truthy at $caller->[1] line $caller->[2].\n"
        unless $out{name};

    die "a codeblock must be provided at $caller->[1] line $caller->[2].\n"
        unless $out{code};

    return \%out;
}

{
    my @BUILD_STACK;

    sub current_build { @BUILD_STACK ? $BUILD_STACK[-1] : undef }
    sub all_builds    { @BUILD_STACK }

    sub build_group {
        my $args = parse_args(args => \@_);

        my $build = Test2::Workflow::Build->new(%$args);
        push @BUILD_STACK => $build;

        my $ok = eval { $args->{code}->(); 1 };
        my $err = $@;

        pop @BUILD_STACK;

        die $err unless $ok;

        return Test2::Workflow::Group->new_from_build($build);
    }
}

1;
