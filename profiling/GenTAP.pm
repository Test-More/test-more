#a small framework for creating TAP emitting workloads for benchmarking by bulk88

use strict;
use warnings;
use constant UVMAX => 2**32; #%Config doesn't have this, this will do
use Time::HiRes qw( sleep );

#void GenTap($time_per_sleep, $sleep_count, $emitter, $test_count)
# time_per_sleep -
#  seconds to sleep when a sleep is triggered, floating point okay and will sleep
#  fractions of a second (uses Time::HiRes)
# sleep_count -
#  integer count of number of times to sleep, the sleeps will be evenly
#  distributed between tests
# emitter -
#   ok - use Test::More::ok()
#   tinyok -  use Test::Tiny::ok() (must faster Test::More)
#   print - use perl core print()
#   block - use perl core print with atleast 4KB of multiline output per print
# test_count -
#   number of tests to run, will be interleaved with sleeps if applicable
sub GenTAP {
    die "usage: GenTAP" if @_ != 4;
    my ($time_per_sleep, $sleep_count, $emitter, $test_count) = @_;
    die "invalid test count" if $test_count >= UVMAX;
    my($testnum, $tests_before_sleep, $tests_left_before_sleep, $buffer, $ok, $is) = (1, UVMAX, UVMAX);

#emmit a plan
    if($emitter eq 'ok') {
        require Test::More;
        Test::More::plan(tests => $test_count);
        $ok = \&Test::More::ok;
    } elsif($emitter eq 'is') {
        require Test::More;
        Test::More::plan(tests => $test_count);
        $is = \&Test::More::is;
    } elsif($emitter eq 'tinyok') {
        require Test::Tiny;
        Test::Tiny->import(tests => $test_count);
        $ok = \&Test::Tiny::ok;
        $emitter = 'ok'; # less branching in main loop
    } else {
        my $plan = "1..$test_count\n";
        if($emitter eq 'print') {
            print $plan;
        } elsif ($emitter eq 'block') {
            $buffer = $plan;
        } else {
            die "unknown emitter";        
        }
    }
    
    $tests_left_before_sleep = $tests_before_sleep = $test_count / $sleep_count if $sleep_count;
    
    while ($testnum <= $test_count) {
# UC 1 random character in each test name for a touch of crazy
# and test output that isn't identical each time, UCing a space produce no change
# which is intentional, since sometimes the line should not be "typo-ed"
        my $testname =  "All work and no play makes Jack a dull boy";
        my $replace = int(rand(length("All work and no play makes Jack a dull boy")));
        substr($testname, $replace, 1, uc(substr($testname, $replace, 1)));
        if ($emitter eq 'ok') {
            &$ok(1, $testname);
        } elsif($emitter eq 'is') {
            &$is(1, 1, $testname);
        } else {
            my $testline = 'ok '.$testnum.' '.$testname."\n";
            if ($emitter eq 'print') {
                print $testline;
            #} elsif ($emitter eq 'block') {
            } else { #checked above
                $buffer .= $testline;
                if(length($buffer) > 4096) {
                    print $buffer;
                    $buffer = '';
                }
            }
        }
        sleep($time_per_sleep), ($tests_left_before_sleep = $tests_before_sleep) if --$tests_left_before_sleep == 0;
        $testnum++;
    }
    
    #flush the buffer in block mode
    print $buffer if $emitter eq 'block' && length($buffer);
}
1;
