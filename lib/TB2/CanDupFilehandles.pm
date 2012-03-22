package TB2::CanDupFilehandles;

use TB2::Mouse ();
use TB2::Mouse::Role;
with 'TB2::CanTry';

our $VERSION = '1.005000_003';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::CanDupFilehandles - A role for duplicating filehandles

=head1 SYNOPSIS

    package Some::Thing;

    use TB2::Mouse;
    with 'TB2::CanDupFilehandles';

=head1 DESCRIPTION

This role supplies a class with the ability to duplicate filehandles
in a way which also copies IO layers such as UTF8.

It's most handy for Streamers.

=head1 METHODS

=head3 dup_filehandle

    my $duplicate = $obj->dup_filehandle($src);
    my $duplicate = $obj->dup_filehandle($src, $duplicate);

Creates a duplicate filehandle including copying any IO layers.

If you hand it an existing $duplicate filehandle it will overwrite it
and return it.  If it's undef, it will return a new one.  This
is handy as it will preserve the glob and fileno.

=cut

sub dup_filehandle {
    my $self = shift;
    my($fh, $dup) = @_;

    open( $dup, ">&", $fh ) or die "Can't dup $fh:  $!";

    $self->_copy_io_layers( $fh, $dup );

    return $dup;
}


=head3 autoflush

    $obj->autoflush($fh);

Turns on autoflush for a filehandle.

=cut

sub autoflush {
    my $self = shift;
    my $fh   = shift;

    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;

    return;
}


sub _copy_io_layers {
    my( $self, $src, $dst ) = @_;

    $self->try(
        sub {
            require PerlIO;
            my @src_layers = PerlIO::get_layers($src);

            _apply_layers($dst, @src_layers) if @src_layers;
        }
    );

    return;
}

sub _apply_layers {
    my ($fh, @layers) = @_;
    my %seen;
    my @unique = grep { defined $_ } grep { $_ ne 'unix' and !$seen{$_}++ } @layers;
    binmode($fh, join(":", "", "raw", @unique));
}

no TB2::Mouse::Role;

1;
