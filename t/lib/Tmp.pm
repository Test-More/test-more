package Tmp;

require Exporter;
@ISA    = qw(Exporter);
@EXPORT = qw(tmpfile);

use strict;
use File::Spec;


sub tmpfile {
    my $file = shift;

    my $tmpdir = $ENV{AEGIS_TMPDIR} || File::Spec->curdir;

    return File::Spec->catfile($tmpdir, $file);
}


1;
