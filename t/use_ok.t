#!/usr/bin/perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = qw(../lib ../lib/Test/Simple/t/lib);
    }
    else {
        unshift @INC, 't/lib';
    }
}

use Test::More tests => 22;

# Using Symbol because it's core and exports lots of stuff.
{
    package Foo::one;
    ::use_ok("Symbol");
    ::ok( defined &gensym,        'use_ok() no args exports defaults' );
}

{
    package Foo::two;
    ::use_ok("Symbol", qw(qualify));
    ::ok( !defined &gensym,       '  one arg, defaults overridden' );
    ::ok( defined &qualify,       '  right function exported' );
}

{
    package Foo::three;
    ::use_ok("Symbol", qw(gensym ungensym));
    ::ok( defined &gensym && defined &ungensym,   '  multiple args' );
}

{
    package Foo::four;
    my $warn; local $SIG{__WARN__} = sub { $warn .= shift; };
    ::use_ok("constant", qw(foo bar));
    ::ok( defined &foo, 'constant' );
    ::is( $warn, undef, 'no warning');
}

{
    package Foo::five;
    ::use_ok("Symbol", 1.02);
}

{
    package Foo::six;
    ::use_ok("NoExporter", 1.02);
}

{
    package Foo::seven;
    local $SIG{__WARN__} = sub {
        # Old perls will warn on X.YY_ZZ style versions.  Not our problem
        warn @_ unless $_[0] =~ /^Argument "\d+\.\d+_\d+" isn't numeric/;
    };
    ::use_ok("Test::More", 0.47);
}

{
    package Foo::eight;
    local $SIG{__DIE__};
    ::use_ok("SigDie");
    ::ok(defined $SIG{__DIE__}, '  SIG{__DIE__} preserved');
}

{
    BEGIN { use_ok 'strict' }
    is eval { ()=@{"!#%^"}; 1 }, undef, 'use_ok with pragma';
}
is eval { ()=@{"!#%^"}; 1 }, 1, 'pragmata enabled by use_ok are lexical'; 

{
    BEGIN { use_ok 'strict', 1 }
    is eval { ()=@{"!#%^"}; 1 }, undef, 'use_ok with pragma and version';
}

{
    package that_cares_about_line_numbers;
    my($pack,$line,$file);
    sub import { ($pack,$file,$line) = caller }
    my $p = __PACKAGE__;
    my $tn = "package, file and line number from caller within import";
    $INC{"$p.pm"}++;
    # Keep this all on one line:
  ::use_ok$p; ::is("$pack $file $line",join(" ",$p,__FILE__,__LINE__),$tn);
}
