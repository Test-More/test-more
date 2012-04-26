package TB2::CanOpen;

use TB2::Mouse ();
use TB2::Mouse::Role;

our $VERSION = '1.005000_005';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=begin private

=head3 open

    my $fh = $obj->open($mode, $file);

Works like L<perlfunc/open> but ensures global variables like C<$!>
and C<$@> are not blown over.

If the open fails, it will throw an exception containing C<$!>.

=cut

sub open {
    my $self = shift;
    my($mode, $file) = @_;

    local $!;
    open my $fh, $mode, $file or die "$!\n";

    return $fh;
}

=end private

=cut

1;
