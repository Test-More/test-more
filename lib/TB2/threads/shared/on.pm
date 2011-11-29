package TB2::threads::shared::on;

use strict;

our $VERSION = '1.005000_002';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

require threads::shared;
use Scalar::Util qw(refaddr reftype blessed);

# shared_clone() was introduced to threads::shared pretty
# recently (5.10.1 and 5.8.9) so we'll duplicate its functionality here.
if ( !threads::shared->can("shared_clone") ) {
    my $make_shared;            # it referrs to itself
    $make_shared = sub {
        my ($item, $cloned) = @_;

        # Just return the item if:
        # 1. Not a ref;
        # 2. Already shared; or
        # 3. Not running 'threads'.
        return $item if !ref $item;

        # Check for previously cloned references
        #   (this takes care of circular refs as well)
        my $addr = refaddr($item);
        if (exists($cloned->{$addr})) {
            # Return the already existing clone
            return $cloned->{$addr};
        }

        # Make copies of array, hash and scalar refs and refs of refs
        my $copy;
        my $ref_type = reftype($item);

        # Copy an array ref
        if ($ref_type eq 'ARRAY') {
            # Make empty shared array ref
            $copy = &share([]);
            # Add to clone checking hash
            $cloned->{$addr} = $copy;
            # Recursively copy and add contents
            push(@$copy, map { $make_shared->($_, $cloned) } @$item);
        }

        # Copy a hash ref
        elsif ($ref_type eq 'HASH') {
            # Make empty shared hash ref
            $copy = &share({});
            # Add to clone checking hash
            $cloned->{$addr} = $copy;
            # Recursively copy and add contents
            foreach my $key (keys(%{$item})) {
                $copy->{$key} = $make_shared->($item->{$key}, $cloned);
            }
        }

        # Copy a scalar ref
        elsif ($ref_type eq 'SCALAR') {
            $copy = \do{ my $scalar = $$item; };
            share($copy);
            # Add to clone checking hash
            $cloned->{$addr} = $copy;
        }

        # Copy of a ref of a ref
        elsif ($ref_type eq 'REF') {
            # Special handling for $x = \$x
            if ($addr == refaddr($$item)) {
                $copy = \$copy;
                share($copy);
                $cloned->{$addr} = $copy;
            } else {
                my $tmp;
                $copy = \$tmp;
                share($copy);
                # Add to clone checking hash
                $cloned->{$addr} = $copy;
                # Recursively copy and add contents
                $tmp = $make_shared->($$item, $cloned);
            }

        }
        else {
            require Carp;
            Carp::croak("Unsupported ref type: ", $ref_type);
        }

        # If input item is an object, then bless the copy into the same class
        if (my $class = blessed($item)) {
            bless($copy, $class);
        }

        # Clone READONLY flag
        if ($ref_type eq 'SCALAR') {
            if (Internals::SvREADONLY($$item)) {
                Internals::SvREADONLY($$copy, 1) if ($] >= 5.008003);
            }
        }
        if (Internals::SvREADONLY($item)) {
            Internals::SvREADONLY($copy, 1) if ($] >= 5.008003);
        }

        return $copy;
    };

    *shared_clone = sub { return $make_shared->(shift, {}) };
}
else {
    *shared_clone = threads::shared->can("shared_clone");
}

# import share()
*share = \&threads::shared::share;

1;
