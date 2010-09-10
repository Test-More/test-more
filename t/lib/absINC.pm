package absINC;

use strict;
use warnings;

use File::Spec;

for my $idx (0..$#INC) {
    my $dir = $INC[$idx];
    next if ref $dir;
    next if File::Spec->file_name_is_absolute($dir);

    $INC[$idx] = File::Spec->rel2abs($dir);
}


=head1 NAME

absINC - Makes all paths in @INC absolute

=head1 SYNOPSIS

    use lib 't/lib';
    use absINC;

=head1 DESCRIPTION

This is used if your test is going to chdir around.  If @INC contains
relative paths any C<require>s in the code might fail.

=cut

1;
