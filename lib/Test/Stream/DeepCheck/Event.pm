package Test::Stream::DeepCheck::Event;
use strict;
use warnings;

use Test::Stream::DeepCheck::Meta::Event;
use Test::Stream::DeepCheck::Object;
use Test::Stream::HashBase(
    base => 'Test::Stream::DeepCheck::Object',
);

sub deep        { 1 }
sub error_type  { 'Event' }
sub as_string   { "An event object" }
sub meta_class  { 'Test::Stream::DeepCheck::Meta::Event' }
sub object_base { 'Test::Stream::Event' }

sub post_check {
    my $self = shift;
    my ($res, $got, $state) = @_;

    if ($got && $got->isa('Test::Stream::Event')) {
        my $trace = $got->debug->trace;
        unshift @{$res->diag} => "- Event created $trace";
    }
}

1;
