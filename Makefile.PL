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
    if( $Config{useithreads} && $PACKAGE_VERSION < $LAST_THREAD_CHANGE ) {
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

my $install_dir = $] >= 5.006002 && $] < 5.012000 ? 'perl' : 'site';

WriteMakefile(
    NAME            => $PACKAGE,

    VERSION_FROM    => "lib/$PACKAGE_FILE.pm",
    ABSTRACT_FROM   => "lib/$PACKAGE_FILE.pm",
    AUTHOR          => 'Michael G Schwern <schwern@pobox.com>',

    ($mm_ver >= 6.31 ? (LICENSE => 'perl') : ()),

    PREREQ_PM       => { 
        'Test::Harness'         => 2.03,
        'Scalar::Util'          => 1.13,
        %Prereqs
    },

    INSTALLDIRS => $install_dir,
    test => { RECURSIVE_TEST_FILES => 1 },

    ($mm_ver < 6.48 ? () : (MIN_PERL_VERSION => 5.008001)),

    ($mm_ver < 6.46 ? () : (META_MERGE => {
        resources => {
            license     =>      'http://dev.perl.org/licenses/',
            homepage    =>      'http://github.com/Test-More/test-more/',
            bugtracker  =>      'http://github.com/Test-More/test-more/issues/',
            repository  =>      'http://github.com/Test-More/test-more/',
            MailingList =>      'http://lists.perl.org/list/perl-qa.html',
        },

        x_breaks => {
            # entries here declared like conflicts (see CPAN::Meta::Spec): the
            # version range describes the versions of the module that are
            # *incompatible* with our Test::More.
            'Test::Aggregate'           => '<= 0.371',  # still broken: see RT#100035
            'Test::Bomb'                => '<= 0.007',  # still broken: see GH#449
            'Test::Builder:Clutch'      => '<= 0.06',
            'Test::Classy'              => '<= 0.09',
            'Test::DBIx::Class::Schema' => '<= 1.0.6',  # still broken: see GH#481
            'Test::FITesque'            => '<= 0.03',   # still broken: see GH485
            'Test::FileReferenced'      => '<= 0.02',   # still broken: see RT#100501
            'Test::Flatten'             => '<= 0.11',   # still broken: see GH#498
            'Test::Kit'                 => '<= 2.12',
            'Test::Kwalitee'            => '<= 1.18',
            'Test::Modern'              => '<= 0.011',
            'Test::Module::Used'        => '<= 0.2.4',
            'Test::Moose'               => '<= 2.1209',
            'Test::Moose::More'         => '<= 0.024',
            'Test::More::Prefix'        => '<= 0.003',  # still broken: see RT#90361
            'Test::ParallelSubtest'     => '<= 0.05',   # still broken: see RT#100757
            'Test::Pretty'              => '<= 0.30',   # still broken: see GH#505
            'Test::Spec'                => '<= 100034', # still broken: see RT#100034
            'Test::Wrapper'             => '<= 0.3.0',  # still broken: see GH#489
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


    # Test with multiple versions of perl before releasing
    sub dist_test {
        my $self = shift;

        my $make = $self->SUPER::dist_test(@_);
        return $make unless $ENV{AUTHOR_TESTING} and $ENV{AUTHOR_TESTING} eq 'MSCHWERN';

        # Strip off all the whitespace at the end, we'll put our own in.
        $make =~ s{\s+\z}{\n};

        my @perls = qw(
            perl5.20.0
            perl5.18.2
            perl5.16.3
            perl5.14.4
            perl5.12.5
            perl5.10.1
            perl5.8.9
        );

        for my $perl (@perls) {
            if( !`which $perl` ) {
                print STDERR "Missing $perl";
                next;
            }
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
