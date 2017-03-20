package Test2::Event::Pass;
use strict;
use warnings;

our $VERSION = '1.302079';

use Test2::EventFacet::Info;

BEGIN {
    require Test2::Event;
    our @ISA = qw(Test2::Event);
    *META_KEY = \&Test2::Util::ExternalMeta::META_KEY;
}

use Test2::Util::HashBase qw{ -name -info };

##############
# Old API
sub summary          { "pass" }
sub increments_count { 1 }
sub causes_fail      { 0 }
sub diagnostics      { 0 }
sub no_display       { 0 }
sub subtest_id       { undef }
sub terminate        { () }
sub global           { () }
sub sets_plan        { () }

##############
# New API

sub add_info {
    my $self = shift;

    for my $in (@_) {
        $in = {%$in} if ref($in) ne 'ARRAY';
        $in = Test2::EventFacet::Info->new($in);

        push @{$self->{+INFO}} => $in;
    }
}

sub facet_data {
    my $self = shift;

    my $out = $self->common_facet_data;

    $out->{about}->{details} = 'pass';

    $out->{assert} = {pass => 1, details => $self->{+NAME}};

    $out->{info} = [map {{ %{$_} }} @{$self->{+INFO}}] if $self->{+INFO};

    return $out;
}

1;
