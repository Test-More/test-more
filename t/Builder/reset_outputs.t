#!perl -w

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = ('../lib', 'lib');
    }
    else {
        unshift @INC, 't/lib';
    }
}

use Test::Builder;
use Test::More 'no_plan';

{
    my $tb = Test::Builder->create();

    my @methods = qw(output failure_output todo_output);

    # Store the original output filehandles
    my %original_outputs;
    for my $method (@methods) {
        $original_outputs{$method} = $tb->$method();
    }

    # Change them all
    open my $fh, ">", "dummy_file.tmp";
    END { 1 while unlink "dummy_file.tmp"; }
    for my $method (@methods) {
        $tb->$method($fh);
        is $tb->$method(), $fh;
    }

    # Reset them
    $tb->reset_outputs;

    for my $method (@methods) {
        is $tb->$method(), $original_outputs{$method}, "reset_outputs() resets $method";
    }
}
