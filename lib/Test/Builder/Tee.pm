package Test::Builder::Tee;

# A cheap implementation of IO::Tee.

sub TIEHANDLE {
    my($class, @refs) = @_;

    my @fhs;
    for my $ref (@refs) {
        local $!;
        open my $fh, ">>", $ref or die $!;
        push @fhs, $fh;
    }

    my $self = [@fhs];
    return bless $self, $class;
}

sub PRINT {
    my $self = shift;

    print $_ @_ for @$self;
}

sub PRINTF {
    my $self   = shift;
    my $format = shift;

    printf $_ @_ for @$self;
}

1;
