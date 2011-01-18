#!/usr/bin/perl -w

use 5.008001;

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

    INSTALLDIRS     => 'perl',

    test        => {
        TESTS           => 't/*.t t/*/*.t t/*/*/*.t',
    },

    ($mm_ver < 6.48 ? () : (MIN_PERL_VERSION => '5.8.1')),

    ($mm_ver < 6.46 ? () : (META_MERGE => {
        resources => {
            license     =>      'http://dev.perl.org/licenses/',
            homepage    =>      'http://test-more.googlecode.com',
            bugtracker  =>      'http://github.com/schwern/test-more/issues/labels/Test-Builder2',
            repository  =>      'http://github.com/schwern/test-more/tree/Test-Builder2',
            MailingList =>      'http://groups.google.com/group/test-more-users',
        },
        no_index => {
            directory => ["lib/Test/Builder2/Mouse/"],
            file      => ["lib/Test/Builder2/Mouse.pm"],
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

.PHONY: Mouse

Mouse:
	$(PERL) "-MMousse::Maker" -e make_mousse 'Test::Builder2::Mouse' > lib/Test/Builder2/Mouse.pm

MAKE
    }


    # Test with multiple versions of perl before releasing
    sub dist_test {
        my $self = shift;

        my $make = $self->SUPER::dist_test(@_);
        return $make unless $ENV{AUTHOR_TESTING} and $ENV{AUTHOR_TESTING} eq 'MSCHWERN';

        # Strip off all the whitespace at the end, we'll put our own in.
        $make =~ s{\s+\z}{\n};

        my @perls = qw(
            perl5.8.8
            perl5.8.9
            perl5.10.0
            perl5.10.1
            perl5.12.0
            perl5.12.1
        );

        for my $perl (@perls) {
            $make .= sprintf <<'END', $perl;
	cd $(DISTVNAME) && $(MAKE) clean && %s Makefile.PL && PERL_RELEASING=0 $(MAKE) test $(PASTHRU)
END
        }

        # Rebuild so subsequent make commands work
        $make .= <<'END';
	$(MAKE) realclean
	$(FULLPERLRUN) Makefile.PL
	$(MAKE)
END

        $make .= "\n";

        return $make;
    }
}
