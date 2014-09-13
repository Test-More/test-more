package Test::Stream::Carp;
use strict;
use warnings;

use Test::Stream::Exporter;

export croak   => sub { require Carp; goto &Carp::croak };
export confess => sub { require Carp; goto &Carp::confess };
export cluck   => sub { require Carp; goto &Carp::cluck };
export carp    => sub { require Carp; goto &Carp::carp };

1;
