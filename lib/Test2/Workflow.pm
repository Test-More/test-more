package Test2::Workflow;
use strict;
use warnings;

our @EXPORT_OK = qw/parse_args current_build all_builds build root_build init_root/;
use base 'Exporter';

use Test2::Workflow::Build;
use Test2::Workflow::Task::Group;

sub parse_args {
    my %input = @_;
    my $args = delete $input{args};
    my %out;
    my %props;

    my $caller = $out{frame} = $input{caller} || caller(defined $input{level} ? $input{level} : 1);
    $out{lines} = [$caller->[2]];

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
            name  => $pkg,
            flat  => 1,
            iso   => 0,
            async => 0,
            %args,
        );

        return $ROOT_BUILDS{$pkg};
    }

    sub build {
        my %params = @_;
        my $args = parse_args(%params);

        my $build = Test2::Workflow::Build->new(%$args);
        push @BUILD_STACK => $build;

        my $st;
        unless ($args->{flat}) {
            $st = Test2::AsyncSubtest->new(name => "$args->{name} (During Build)");
            $st->start;
        }

        my $ok = eval { $args->{code}->(); 1 };
        my $err = $@;

        if ($st) {
            $st->stop;
            $st->finish(collapse => 1, silent => !(@{$st->events} || $st->hub->failed) );
        }

        delete $build->{stash};

        pop @BUILD_STACK;

        die $err unless $ok;

        return $build;
    }
}

1;

__END__
