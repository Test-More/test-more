package Test::Builder::Threads;
use strict;
use warnings;

# Make Test::Builder thread-safe for ithreads.
BEGIN {
    use Config;
    # Load threads::shared when threads are turned on.
    # 5.8.0's threads are so busted we no longer support them.
    if( $] >= 5.008001 && $Config{useithreads} && $INC{'threads.pm'} ) {
        require threads::shared;

        # Hack around YET ANOTHER threads::shared bug.  It would
        # occasionally forget the contents of the variable when sharing it.
        # So we first copy the data, then share, then put our copy back.
        *share = sub (\[$@%]) {
            my $type = ref $_[0];
            my $data;

            if( $type eq 'HASH' ) {
                %$data = %{ $_[0] };
            }
            elsif( $type eq 'ARRAY' ) {
                @$data = @{ $_[0] };
            }
            elsif( $type eq 'SCALAR' ) {
                $$data = ${ $_[0] };
            }
            else {
                die( "Unknown type: " . $type );
            }

            $_[0] = &threads::shared::share( $_[0] );

            if( $type eq 'HASH' ) {
            }
            elsif( $type eq 'ARRAY' ) {
                @{ $_[0] } = @$data;
            }
            elsif( $type eq 'SCALAR' ) {
                ${ $_[0] } = $$data;
            }
            else {
                die( "Unknown type: " . $type );
            }

            return $_[0];
        };
    }
    # 5.8.0's threads::shared is busted when threads are off
    # and earlier Perls just don't have that module at all.
    else {
        *share = sub { return $_[0] };
        *lock  = sub { 0 };
    }
}

sub import {
    my $class = shift;
    my $caller = caller;

    no strict 'refs';
    *{"$caller\::share"} = $class->can('share') if $class->can('share');
    *{"$caller\::lock"}  = $class->can('lock')  if $class->can('lock');
}

1;
