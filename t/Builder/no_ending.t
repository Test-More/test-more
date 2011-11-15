use Test::Builder;

BEGIN {
    if( $ENV{PERL_CORE} ) {
        chdir 't';
        @INC = '../lib';
    }
}

BEGIN {
    my $t = Test::Builder->new;
    $t->no_ending(1);
}

use Test::More tests => 3;

# Normally, Test::More would yell that we ran too few tests, but we
# suppressed the ending diagnostics.
ok !Test::More->builder->formatter->show_ending_commentary,
  "TAP formatter told not to do ending commentary";
print "ok 2\n";
print "ok 3\n";
