package TieOut;

use strict;

sub TIEHANDLE {
    my $scalar = '';
    bless( \$scalar, $_[0] );
}

sub PRINT {
    my $self = shift;

    # Fully emulate $\ + print().
    my $ors = defined $\ ? $\ : '';
    
    $$self .= join( '', @_, $ors );
}

sub PRINTF {
    my $self = shift;
    my $fmt  = shift;
    $$self .= sprintf $fmt, @_;
}

sub FILENO { }

sub read {
    my $self = shift;
    my $data = $$self;
    $$self = '';
    return $data;
}

1;
