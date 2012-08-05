#!/usr/bin/perl -w

use strict;
use warnings;

BEGIN { require "t/test.pl" }

# A mocked Test::Builder that does nothing when used by import
{
    package MyDummyBuilder;

    require Test::Builder;
    our @ISA = qw(Test::Builder);

    sub exported_to {}
    sub plan        {
        my $self = shift;
        $self->{__plan_args} = [@_];
    }
}

my $Import_Extra_Code = sub {};
{
    package MyTest;

    require Test::Builder::Module;
    our @ISA = qw(Test::Builder::Module);

    sub builder {
        return MyDummyBuilder->new;
    }

    sub import_extra {
        $Import_Extra_Code->(@_);
    }
}


note "import_extra with no_plan"; {
    MyTest->import("no_plan");
    is_deeply( MyTest->builder->{__plan_args}, [no_plan => 1] );
}


note "import_extra can rewrite args"; {
    $Import_Extra_Code = sub {
        my $class = shift;
        my $args  = shift;
        my %args  = @$args;
        delete $args{__special};
        @$args = %args;
        return;
    };
    MyTest->import(__special => 23, tests => 5);
    is_deeply( MyTest->builder->{__plan_args}, [tests => 5] );
}

done_testing;
