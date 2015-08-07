package Test::Stream::Workflow::Unit;
use strict;
use warnings;

use Test::Stream::Sync;
use Test::Stream::Context();
use Test::Stream::DebugInfo;

use Carp qw/confess/;
use Scalar::Util qw/reftype/;

use Test::Stream::HashBase(
    accessors => [qw{
        name meta type wrap stash
        package file start_line end_line
        post
        modify
        buildup
        primary
        teardown
    }],
);

sub init {
    $_[0]->{+META} ||= {};

    for (NAME, PACKAGE, FILE, START_LINE, END_LINE) {
        confess "$_ is a required attribute" unless $_[0]->{$_}
    }
}

sub contains {
    my $self = shift;
    my ($thing) = @_;
    my ($file, $line, $name);
    if ($thing =~ m/^(\S+) (\d+)$/) {
        ($file, $line) = ($1, $2);
    }
    elsif ($thing =~ m/^\d+$/) {
        $line = $thing;
    }
    else {
        $name = $thing;
    }

    return $self->_contains($file, $line, $name);
}

sub _contains {
    my $self = shift;
    my ($file, $line, $name) = @_;

    my $name_ok = !defined($name) || $self->{+NAME} eq $name;
    my $file_ok = !defined($file) || $self->{+FILE} eq $file;

    my $line_ok = !defined($line) || (
        $line >= $self->{+START_LINE}
        && ($self->{+END_LINE} . "" eq 'EOF' || $line <= $self->{+END_LINE})
    );

    my $child_ok = 0;
    for my $stash (MODIFY(), BUILDUP(), PRIMARY(), TEARDOWN()) {
        my $set = $self->$stash || next;
        next unless ref $set && reftype($set) eq 'ARRAY';
        for my $unit (@$set) {
            $child_ok = 1 if $unit->_contains($file, $line, $name);
        }
    }

    return $child_ok || ($name_ok && $file_ok && $line_ok);
}

sub do_post {
    my $self = shift;

    my $post = delete $self->{+POST} || return;
    $_->($self) for @$post;
}

for my $type (MODIFY(), BUILDUP(), PRIMARY(), TEARDOWN()) {
    no strict 'refs';
    *{"add_$type"} = sub {
        use strict;
        my $self = shift;
        $self->{$type} ||= [];
        push @{$self->{$type}} => @_;
    };
}

sub add_post {
    my $self = shift;
    confess "post units only apply to group units"
        unless $self->type eq 'group';
    $self->{post} ||= [];
    push @{$self->{post}} => @_;
}

sub debug {
    my $self = shift;

    my $stack = Test::Stream::Sync->stack;
    my $hub   = $stack->top;

    return Test::Stream::DebugInfo->new(
        frame       => [@$self{qw/package file start_line name/}],
        todo        => $hub->get_todo,
        skip        => $self->meta->{skip},
        parent_todo => $hub->parent_todo,
        detail => "in block '$self->{+NAME}' defined in $self->{+FILE} (Approx) lines $self->{+START_LINE} -> $self->{+END_LINE}"
    );
}

sub context {
    my $self = shift;

    my $stack = Test::Stream::Sync->stack;
    my $hub   = $stack->top;

    my $ref;
    if(my $todo = $self->meta->{todo}) {
        $ref = $hub->set_todo($todo);
    }

    my $dbg = $self->debug;

    my $ctx = Test::Stream::Context->new(
        stack => $stack,
        hub   => $hub,
        debug => $dbg,
    );

    # Stash the todo ref in the context so that it goes away with the context
    $ctx->{_todo_ref} = $ref;

    return $ctx;
}

1;
