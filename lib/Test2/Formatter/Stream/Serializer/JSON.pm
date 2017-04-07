package Test2::Formatter::Stream::Serializer::JSON;
use strict;
use warnings;

BEGIN {
    local $@ = undef;
    my $ok = eval {
        require JSON::MaybeXS;
        JSON::MaybeXS->import('JSON');
        1;
    };

    $ok ||= eval {
        require JSON::PP;
        *JSON = sub() { 'JSON::PP' };
    };

    die "Could not find either JSON::MaybeXS or JSON::PP, you must install a JSON library before using " . __PACKAGE__ . "\n"
        unless $ok;
}

use Test2::Util::HashBase qw/encoder/;

sub init {
    my $self = shift;

    return if $self->{+ENCODER};

    my $J = JSON->new;
    $J->indent(0);
    $J->convert_blessed(1);
    $J->allow_blessed(1);

    $self->{+ENCODER} = $J;
}

sub send {
    my $self = shift;
    my ($io, $f, $num, $e) = @_;

    # Any unknown blessed things will be stringified
    my $json = eval {
        no warnings 'once';
        local *UNIVERSAL::TO_JSON = sub { "$_[0]" };
        $self->encoder->encode({facets => $f, number => $num})
    } or die "Error encoding JSON: $@";

    print $io "$json\n";
}

1;
