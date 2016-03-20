package Test2::Workflow;
use strict;
use warnings;

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
