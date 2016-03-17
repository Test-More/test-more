package Test2::Workflow::Build;
use strict;
use warnings;

use Test2::Workflow::Task::Group;

our @BUILD_FIELDS;

BEGIN {
    @BUILD_FIELDS = qw{
        primary         variant
        setup           teardown
        variant_setup   variant_teardown
        primary_setup   primary_teardown
    };
}

use base 'Test2::Workflow::Task';
use Test2::Util::HashBase @BUILD_FIELDS;

sub init {
    my $self = shift;

    {
        local $Carp::CarpLevel = $Carp::CarpLevel + 1;
        $self->SUPER::init();
    }

    $self->{$_} ||= [] for @BUILD_FIELDS;
}

for my $field (@BUILD_FIELDS) {
    my $code = sub {
        my $self = shift;
        push @{$self->{$field}} => @_;
    };
    no strict 'refs';
    *{"add_$field"} = $code;
}

sub compile {
    my $self = shift;
    my ($primary_setup, $primary_teardown) = @_;
    $primary_setup    ||= [];
    $primary_teardown ||= [];

    my $variant          = delete $self->{+VARIANT};
    my $setup            = delete $self->{+SETUP};
    my $teardown         = delete $self->{+TEARDOWN};
    my $variant_setup    = delete $self->{+VARIANT_SETUP};
    my $variant_teardown = delete $self->{+VARIANT_TEARDOWN};

    $primary_setup = [@$primary_setup, @{delete $self->{+PRIMARY_SETUP}}];
    $primary_teardown = [@{delete $self->{+PRIMARY_TEARDOWN}}, @$primary_teardown];

    # Get primaries in order.
    my $primary = [
        map {
            $_->isa(__PACKAGE__)
                ? $_->compile($primary_setup, $primary_teardown)
                : $_;
        } @{delete $self->{+PRIMARY}},
    ];

    if (@$primary_setup || @$primary_teardown) {
        $primary = [
            map {
                $_->isa('Test2::Workflow::Task::Action') ? Test2::Workflow::Task::Group->new(
                    before  => $primary_setup,
                    primary => [ $_ ],
                    take    => $_,
                    after   => $primary_teardown,
                ) : $_;
            } @$primary
        ];
    }

    # Build variants
    if (@$variant) {
        $primary = [
            map {
                Test2::Workflow::Task::Group->new(
                    before  => $variant_setup,
                    primary => $primary,
                    after   => $variant_teardown,
                    variant => $_,
                    take    => $_,
                );
            } @$variant
        ];
    }

    return Test2::Workflow::Task::Group->new(
        %$self,
        before  => $setup,
        after   => $teardown,
        primary => $primary,
    );
}

1;


__END__

before_all
    before_case
    case
        before_each
        test
        after_each
    after_case
after_all

g {
    before => before_all
    primary => [
        g {
            before => before_case
            primary => [
                case
                g {
                    before => before_each
                    primary => [
                        test
                    ]
                    after => after_each
                }
            ]
            after  => after_case
        }
    ]
    after => after_all
}

build {
    setup            - before_all
    teardown         - after_all

    variant_setup    - before_case
    variant_teardown - after_case

    primary_setup    - before_each
    primary_teardown - after_each

    variants         - case
    primaries        - test
}

$out{code}
$out{frame}
$out{lines}
$out{name}




use Test2::Util::HashBase qw/code frame _info _lines/;
use Test2::Util::HashBase qw/name flat async iso todo skip scaffold/;
