# A template for Makefile.PL used by Arena Networks.
# - Set the $PACKAGE variable to the name of your module.
# - Set $LAST_API_CHANGE to reflect the last version you changed the API 
#   of your module.
# - Fill in your dependencies in PREREQ_PM
# Alternatively, you can say the hell with this and use h2xs.

use 5.004;

use ExtUtils::MakeMaker;

$PACKAGE = 'Test::Simple';
($PACKAGE_FILE = $PACKAGE) =~ s|::|/|g;
$LAST_API_CHANGE = 0.34;

eval "require $PACKAGE";

unless ($@) { # Make sure we did find the module.
    if( ${$PACKAGE.'::VERSION'} < $LAST_API_CHANGE ) {
        print <<"CHANGE_WARN";

NOTE: There have been API changes between this version and any older
than version $LAST_API_CHANGE!  Please read the Changes file if you
are upgrading from a version older than $LAST_API_CHANGE.

CHANGE_WARN

        sleep 5;
    }
}

WriteMakefile(
    NAME            => $PACKAGE,
    VERSION_FROM    => "lib/$PACKAGE_FILE.pm", # finds $VERSION
    PREREQ_PM       => { 
                        Test::Harness   => 2.03,
                        File::Spec      => 0.6,
                       },
    # Added to the core somewhere around 5.7.2.
    INSTALLDIRS     => $] >= 5.00702 ? 'perl' : 'site'
);


{
    package MY;

    sub test_via_harness {
        my($self, $orig_perl, $tests) = @_;

        my @perls = ($orig_perl);
        push @perls, qw(
                        perl5.4.0
                        perl5.5.3
                        perl5.6.0
                        perl5.6.1
                        perl
                        perl5.8.0
                        perl5.8.0-ithreads
                        bleadperl
                       )
          if $ENV{PERL_TEST_ALL};

        my $out;
        foreach my $perl (@perls) {
            $out .= $self->SUPER::test_via_harness($perl, $tests) . "\n";
        }
        $out =~ s{-I\$\(PERL_\w*LIB\)}{}g;

        return $out;
    }
}


# Older versions of Test::Simple were very naughty about being required and
# exitted with 255.  This overrides that behavior so it builds from CPAN.
END {
    exit(0);
}
