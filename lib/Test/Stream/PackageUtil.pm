package Test::Stream::PackageUtil;
use strict;
use warnings;

sub confess { require Carp; goto &Carp::confess }

my @SLOTS = qw/HASH SCALAR ARRAY IO FORMAT CODE/;
my %SLOTS = map {($_ => 1)} @SLOTS;

sub import {
    my $caller = caller;
    no strict 'refs';
    *{"$caller\::package_sym"}       = \&package_sym;
    *{"$caller\::package_purge_sym"} = \&package_purge_sym;
    1;
}

sub package_sym {
    my ($pkg, $slot, $name) = @_;
    confess "you must specify a package" unless $pkg;
    confess "you must specify a symbol type" unless $slot;
    confess "you must specify a symbol name" unless $name;
    
    confess "'$slot' is not a valid symbol type! Valid: " . join(", ", @SLOTS)
        unless $SLOTS{$slot};

    no warnings 'once';
    no strict 'refs';
    return *{"$pkg\::$name"}{$slot};
}

sub package_purge_sym {
    my ($pkg, @pairs) = @_;

    for(my $i = 0; $i < @pairs; $i += 2) {
        my $purge = $pairs[$i];
        my $name  = $pairs[$i + 1];

        confess "'$purge' is not a valid symbol type! Valid: " . join(", ", @SLOTS)
            unless $SLOTS{$purge};

        no strict 'refs';
        *CLONE = *{"$pkg\::$name"};
        undef *{"$pkg\::$name"};
        for my $slot (@SLOTS) {
            next if $slot eq $purge;
            *{"$pkg\::$name"} = *CLONE{$slot} if defined *CLONE{$slot};
        }
    }
}

1;
