package Test::Stream::Compare::Event;
use strict;
use warnings;

use Scalar::Util qw/blessed/;

use Test::Stream::Compare::Object;
use Test::Stream::Compare::EventMeta;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare::Object',
    accessors => [qw/etype/],
);

sub name {
    my $self = shift;
    my $etype = $self->etype;
    return "<EVENT: $etype>"
}

sub meta_class  { 'Test::Stream::Compare::EventMeta' }
sub object_base { 'Test::Stream::Event' }

sub got_lines {
    my $self = shift;
    my ($event) = @_;
    return unless $event;
    return unless blessed($event);
    return unless $event->isa('Test::Stream::Event');

    return ($event->debug->line);
}

1;
