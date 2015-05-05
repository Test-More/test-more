#!/usr/bin/perl -w

use 5.008001;

use Config;
use ExtUtils::MakeMaker;
use lib 'lib';

my $PACKAGE = 'Test::Stream';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
my $LAST_API_CHANGE    = 0.48;
my $LAST_THREAD_CHANGE = 0.48;

eval "require $PACKAGE";
my $PACKAGE_VERSION = ${$PACKAGE.'::VERSION'} || die "Could not get version!";

my $mm_ver = $ExtUtils::MakeMaker::VERSION;
if ($mm_ver =~ /_/) { # dev version
    $mm_ver = eval $mm_ver || die $@;
}

# Windows does not expand *.t and MakeMaker only started working around
# that for TESTS in 6.27.  This does not introduce a circular dep
# because MakeMaker ships with its own Test::More.
my %Prereqs;
$Prereqs{'ExtUtils::MakeMaker'} = 6.27 if $^O eq 'MSWin32';

WriteMakefile(
    NAME => $PACKAGE,

    VERSION_FROM  => "lib/$PACKAGE_FILE.pm",
    ABSTRACT_FROM => "lib/$PACKAGE_FILE.pm",
    AUTHOR        => 'Chad Granum <exodist7@gmail.com>',

    ($mm_ver >= 6.31 ? (LICENSE => 'perl') : ()),

    PREREQ_PM       => {
        'Test::Builder' => 1.001014,
        'Test::Harness' => 2.03,
        'Scalar::Util'  => 1.13,
        %Prereqs
    },

    test => { TESTS => 't/*.t t/*/*.t t/*/*/*.t' },

    ($mm_ver < 6.48 ? () : (MIN_PERL_VERSION => 5.008001)),

    ($mm_ver < 6.46 ? () : (META_MERGE => {
        resources => {
            license    => 'http://dev.perl.org/licenses/',
            homepage   => 'http://github.com/Test-More/Test-Stream/',
            bugtracker => 'http://github.com/Test-More/Test-Stream/issues/',
            repository => 'http://github.com/Test-More/Test-Stream/',
        },
    }))
);
