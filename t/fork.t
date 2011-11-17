#!/usr/bin/perl -w

use Test::More;
use Config;

my $Can_Fork = $Config{d_fork} ||
               (($^O eq 'MSWin32' || $^O eq 'NetWare') and
                $Config{useithreads} and 
                $Config{ccflags} =~ /-DPERL_IMPLICIT_SYS/
               );

# Normalize output
local $ENV{HARNESS_ACTIVE} = 1;

if( !$Can_Fork ) {
    plan skip_all => "This system cannot fork";
}
else {
    plan tests => 2;
}


if( my $child = fork ) { # parent
    pass("Only the parent should process the ending, not the child");

    # Wait for the child to finish
    waitpid($child, 0);

    open my $fh, "<", "t/fork_t_$child" or die $!;

    is join("", <$fh>), <<END, "child should not do the ending";
not ok 1 - This should have no effect on the parent

#   Failed test 'This should have no effect on the parent'
#   at $0 line 48.
not ok 2 - For good measure, issue the wrong test count

#   Failed test 'For good measure, issue the wrong test count'
#   at $0 line 49.
END

    close $fh;
    END { unlink "t/fork_t_$child"; }
}
else {
    # Send the child's output to a file.
    open my $fh, ">", "t/fork_t_$$" or die $!;
    my $formatter = Test::More->builder->test_state->formatters->[0];
    $formatter->streamer->output_fh($fh);
    $formatter->streamer->error_fh($fh);

#line 48
    fail("This should have no effect on the parent");
    fail("For good measure, issue the wrong test count");

    # And exit badly
    exit(255);
}
