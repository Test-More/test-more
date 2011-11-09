#!/usr/bin/perl

use strict;
use warnings;

use lib 't/lib';
BEGIN { require 't/test.pl'; }

use Test::Builder2::AssertRecord;

note "Basic construction"; {
    my $record = new_ok "Test::Builder2::AssertRecord", [{
        package         => "Foo",
        line            => 23,
        filename        => "foo.t",
        subroutine      => "main",
    }];

    is $record->package,        "Foo";
    is $record->line,           23;
    is $record->filename,       "foo.t";
    is $record->subroutine,     "main";

    for my $method (qw(package line filename subroutine)) {
        ok !eval { $record->$method(123); 1 }, "Can't change $method";
    }
}


note "No arguments"; {
    ok !eval { Test::Builder2::AssertRecord->new } or diag $@;
}


note "new_from_guess"; {
    my $record = Test::Builder2::AssertRecord->new_from_guess;

    is $record->package,        __PACKAGE__;
    is $record->line,           __LINE__ - 3;
    is $record->filename,       $0;
    is $record->subroutine,     'Test::Builder2::AssertRecord::new_from_guess';
}


note "new_from_guess deeper"; {
    {
        package Foo;

        sub outer { inner() }
        our $line = __LINE__ + 1;
        sub inner { Bar::outer() }
    }
    

    {
        package Bar;

        sub outer { inner() }
        sub inner { return Test::Builder2::AssertRecord->new_from_guess }
    }


    my $record = Foo->outer;
    is $record->package,        'Foo';
    is $record->line,           $Foo::line;
    is $record->filename,       $0;
    is $record->subroutine,     'Bar::outer';    
}

note "new_from_caller"; {
#line 29 baz.t 
    sub baz {
        foo();
    }

#line 39 foo.t
    sub foo {
        bar();
    }

#line 44 bar.t
    sub bar {
        note "caller(0)"; {
            my $record = Test::Builder2::AssertRecord->new_from_caller(0);

            is $record->package,    __PACKAGE__;
            is $record->line,       40;
            is $record->filename,   "foo.t";
            is $record->subroutine, __PACKAGE__."::bar";
        }

        note "caller(1)"; {
            my $record = Test::Builder2::AssertRecord->new_from_caller(1);

            is $record->package,    __PACKAGE__;
            is $record->line,       30;
            is $record->filename,   "baz.t";
            is $record->subroutine, __PACKAGE__."::foo";
        }
    }

    baz();
}


done_testing;
