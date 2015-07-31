package Test::Stream::DeepCheck::Meta::Event;
use strict;
use warnings;

use Test::Stream::DeepCheck::Meta;
use Test::Stream::HashBase(
    base => 'Test::Stream::DeepCheck::Meta',
);

sub get_prop_file    { $_[1]->debug->file }
sub get_prop_line    { $_[1]->debug->line }
sub get_prop_package { $_[1]->debug->package }
sub get_prop_subname { $_[1]->debug->subname }
sub get_prop_skip    { $_[1]->debug->skip }
sub get_prop_todo    { $_[1]->debug->todo }
sub get_prop_trace   { $_[1]->debug->trace }
sub get_prop_tid     { $_[1]->debug->tid }
sub get_prop_pid     { $_[1]->debug->pid }

1;
