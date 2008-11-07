#!/usr/bin/perl -w
# $Id$

use 5.006;

use Config;
use ExtUtils::MakeMaker;

my $PACKAGE = 'Test::Simple';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
my $LAST_API_CHANGE    = 0.48;
my $LAST_THREAD_CHANGE = 0.48;

eval "require $PACKAGE";
my $PACKAGE_VERSION = ${$PACKAGE.'::VERSION'};

unless ($@) { # Make sure we did find the module.
    if( $PACKAGE_VERSION < $LAST_API_CHANGE ) {
        printf <<"CHANGE_WARN", $LAST_API_CHANGE;

NOTE: There have been API changes between this version and any older
than version %s!  Please see the Changes file for details.

CHANGE_WARN

        sleep 5;
    }
    if( $] >= 5.008001 && $Config{useithreads} &&
        $PACKAGE_VERSION < $LAST_THREAD_CHANGE 
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

my $mm_ver = $ExtUtils::MakeMaker::VERSION;
if ($mm_ver =~ /_/) { # dev version
    $mm_ver = eval $mm_ver;
    die $@ if $@;
}


# Windows does not expand *.t and MakeMaker only started working around
# that for TESTS in 6.27.  This does not introduce a circular dep
# because MakeMaker ships with its own Test::More.
my %Prereqs;
$Prereqs{'ExtUtils::MakeMaker'} = 6.27 if $^O eq 'MSWin32';


WriteMakefile(
    NAME            => $PACKAGE,

    VERSION_FROM    => "lib/$PACKAGE_FILE.pm",
    ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm",
    AUTHOR          => 'Michael G Schwern <schwern@pobox.com>',

    ($mm_ver >= 6.31 ? (LICENSE => 'perl') : ()),

    PREREQ_PM       => { 
        Test::Harness   => 2.03,
        %Prereqs
    },

    # Added to the core in 5.7.3 and also 5.6.2.
    INSTALLDIRS     => $] >= 5.006002 ? 'perl' : 'site',

    test        => {
        TESTS           => 't/*.t t/*/*.t',
    },

    ($mm_ver <= 6.45 ? () : (META_MERGE => {
        resources => {
            license     =>      'http://dev.perl.org/licenses/',
            homepage    =>      'http://test-more.googlecode.com',
            bugtracker  =>      'http://code.google.com/p/test-more/issues',
            repository  =>      'http://test-more.googlecode.com/svn/',
            MailingList =>    'http://groups.google.com/group/test-more-users',
        },
    }))
);


{
    package MY;

    sub postamble {
        return <<'MAKE';

perltidy:
	find . -name '*.pm' | xargs perltidy -b
	find . -name '*.pm.bak' | xargs rm

MAKE
    }
}
