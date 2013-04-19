package TB2::CanTry;

use TB2::Mouse ();
use TB2::Mouse::Role;

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


# I'm not ready to publish this.  It doesn't deal with array return
# values from the code or context.

=begin private

=item B<try>

    my $return_from_code          = $obj->try(sub { code });
    my($return_from_code, $error) = $obj->try(sub { code });

Works like eval BLOCK except it ensures it has no effect on the rest
of the test (ie. C<$@> is not set) nor is effected by outside
interference (ie. C<$SIG{__DIE__}>) and works around some quirks in older
Perls.

C<$error> is what would normally be in C<$@>.

It is suggested you use this in place of eval BLOCK.

=cut

sub try {
    my( $self, $code, %opts ) = @_;

    my $error;
    my $return;
    {
        local $!;               # eval can mess up $!
        local $@;               # don't set $@ in the test
        local $SIG{__DIE__};    # don't trip an outside DIE handler.
        $return = eval { $code->() };
        $error = $@;
    }

    die $error if $error and $opts{die_on_fail};

    return wantarray ? ( $return, $error ) : $return;
}

=end private

=cut

no TB2::Mouse::Role;

1;
