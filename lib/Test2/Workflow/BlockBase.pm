package Test2::Workflow::BlockBase;
use strict;
use warnings;

use Test2::Util::HashBase qw/code frame _info _lines/;
use Test2::Util::Sub qw/sub_info/;
use List::Util qw/min max/;
use Carp qw/croak/;

use Test2::Util::Trace();

BEGIN {
    local ($@, $!, $SIG{__DIE__});

    my $set_name = eval { require Sub::Util; Sub::Util->can('set_subname') }
                || eval { require Sub::Name; Sub::Name->can('subname') };

    *set_subname = $set_name ? sub {
        my $self = shift;
        my ($name) = @_;

        $set_name->($name, $self->{+CODE});
        delete $self->{+_INFO};

        return 1;
    } : sub { return 0 };
}

sub init {
    my $self = shift;

    croak "The 'code' attribute is required"
        unless $self->{+CODE};

    croak "The 'frame' attribute is required"
        unless $self->{+FRAME};

    $self->{+_LINES} = delete $self->{lines}
        if $self->{lines};
}

sub file    { shift->info->{file} }
sub lines   { shift->info->{lines} }
sub package { shift->info->{package} }
sub subname { shift->info->{name} }

sub info {
    my $self = shift;

    unless ($self->{+_INFO}) {
        my $info = sub_info($self->code);

        my $frame     = $self->frame;
        my $file      = $info->{file};
        my $lines     = $info->{lines};
        my $pre_lines = $self->{+_LINES};

        if ($pre_lines && @$pre_lines) {
            @$lines = @$pre_lines;
        }
        else {
            @$lines = (
                max(@$lines, $frame->[2]),
                min(@$lines, $frame->[2]),
            ) if $frame->[1] eq $file;
        }

        $self->{+_INFO} = $info;
    }

    return $self->{+_INFO};
}

sub trace {
    my $self = shift;
    return Test2::Util::Trace->new(
        frame  => $self->frame,
        detail => $self->debug,
    );
}

sub debug {
    my $self = shift;
    my $file = $self->file;
    my $lines = $self->lines;

    my $line_str = @$lines == 1 ? "around line $lines->[0]" : "around lines $lines->[0] -> $lines->[1]";
    return "at $file $line_str.";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;
    die "$msg " . $self->debug . "\n";
}

1;
