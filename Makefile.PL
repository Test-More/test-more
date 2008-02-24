#!/usr/bin/perl -w

use 5.006;

use Config;
use ExtUtils::MakeMaker;

$PACKAGE = 'Test::Simple';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
$LAST_API_CHANGE    = 0.48;
$LAST_THREAD_CHANGE = 0.48;

eval "require $PACKAGE";

unless ($@) { # Make sure we did find the module.
    if( ${$PACKAGE.'::VERSION'} < $LAST_API_CHANGE ) {
        printf <<"CHANGE_WARN", $LAST_API_CHANGE;

NOTE: There have been API changes between this version and any older
than version %s!  Please see the Changes file for details.

CHANGE_WARN

        sleep 5;
    }
    if( $] >= 5.008001 && $Config{useithreads} &&
        ${$PACKAGE.'::VERSION'} < $LAST_THREAD_CHANGE 
      ) 
    {
        printf <<"THREAD_WARN", $LAST_THREAD_CHANGE;

NOTE: The behavior of Test::More and threads has changed between this
version and any older than version %s!  Please see the Changes file
for details.

THREAD_WARN

        sleep 5;
    }

}

WriteMakefile(
    NAME            => $PACKAGE,

    VERSION_FROM    => "lib/$PACKAGE_FILE.pm",
    ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm",
    AUTHOR          => 'Michael G Schwern <schwern@pobox.com>',

    PREREQ_PM       => { 
                        Test::Harness   => 2.03,
                       },
    # Added to the core in 5.7.3 and also 5.6.2.
    INSTALLDIRS     => $] >= 5.006002 ? 'perl' : 'site',
    ($ExtUtils::MakeMaker::VERSION >= 6.31 ? (LICENSE => 'perl') : ()),
);
