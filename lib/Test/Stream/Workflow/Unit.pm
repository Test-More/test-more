package Test::Stream::Workflow::Unit;
use strict;
use warnings;

use Test::Stream::Sync();
use Test::Stream::Context();
use Test::Stream::DebugInfo();

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
        is_root
    }],
);

sub init {
    $_[0]->{+META} ||= {};

    for (NAME, PACKAGE, FILE, START_LINE, END_LINE) {
        confess "$_ is a required attribute" unless defined $_[0]->{$_}
    }

    $_[0]->{+STASH} ||= {};
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

    my $post = delete $self->{+POST} or return;
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

sub adjust_lines {
    my $self = shift;

    my $start = $self->{+START_LINE};
    my $end   = $self->{+END_LINE};

    for my $stash (MODIFY(), BUILDUP(), PRIMARY(), TEARDOWN()) {
        my $list = $self->{$stash} or next;
        next unless ref $list;
        next unless reftype($list) eq 'ARRAY';
        next unless @$list;

        my $top = $list->[0] or next;

        my $c_start = $top->start_line;
        my $c_end   = $top->end_line;

        $start = $c_start
            if defined($c_start)
            && $c_start =~ m/^\d+$/
            && $c_start < $start;

        next if $end && "$end" eq 'EOF';
        next unless defined $c_end;

        $end = $c_end
            if ($c_end =~ m/^\d+$/ && $c_end > $end)
            || "$c_end" eq 'EOF';
    }

    if ("$end" eq 'EOF') {
        $start -= 1 if $start != $self->{+START_LINE};
    }
    else {
        $start -= 1 if $start != $end && $start != $self->{+START_LINE};
        $end   += 1 if $end != $start && $end   != $self->{+END_LINE};
    }

    $self->{+START_LINE} = $start;
    $self->{+END_LINE}   = $end;
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
        frame  => [@$self{qw/package file start_line name/}],
        detail => "in block '$self->{+NAME}' defined in $self->{+FILE} (Approx) lines $self->{+START_LINE} -> $self->{+END_LINE}",
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

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Workflow::Unit - Representation of a workflow unit.

=head1 EXPERIMENTAL CODE WARNING

C<This module is still EXPERIMENTAL>. Test-Stream is now stable, but this
particular module is still experimental. You are still free to use this module,
but you have been warned that it may change in backwords incompatible ways.
This message will be removed from this modules POD once it is considered
stable.

=head1 DESCRIPTION

This package is a single unit of work to be done in a workflow. The unit may
contain a codeblock, or many child units.

=head1 METHODS

=over 4

=item $bool = $unit->contains($name)

=item $bool = $unit->contains($line)

=item $bool = $unit->contains("$file $line)

Check if the unit contains (or is) a unit with the given specification. The
specification may be a line number, a filename + line number, or a unit name.
This will return true if either the unit, or one of the child units, matches.

=item $unit->add_modify($other_unit)

=item $unit->add_buildup($other_unit)

=item $unit->add_teardown($other_unit)

These add C<$other_unit> as a child unit. The child is added to the group
specified in the method name.

=item $unit->add_primary($other_unit)

Add a primary unit child. B<Note:> The primary unit is either an arrayref of
other units, or a single coderef. In cases where the primary is a coderef, this
will fail badly.

=item $unit->add_post(sub { ... })

Add a post-build callback.

=item $unit->do_post()

Run (and remove) the post-build callbacks.

=item $dbg = $unit->debug

Generate an L<Test::Stream::Debug> object for this unit.

=item $ctx = $unit->context

Generate a context representing the scope of the unit. B<Note:> this context is
non-canonical.

=item $name = $unit->name

Get the unit name.

=item $hr = $unit->meta

Get the meta hashref, this contains things like 'todo' and 'skip'.

=item $type = $unit->type

Get the unit type.

=item $bool = $unit->wrap

True if the codeblock for this unit is a wrap (around_all, around_each, etc).

=item $hr = $unit->stash

General purpose stash for use in plugins and extensions.

=item $pkg = $unit->package

Package for the unit.

=item $file = $unit->file

Filename for the unit

=item $start = $unit->start_line

Starting line for the unit.

=item $end = $unit->end_line

Ending line number for the unit. B<Note:> This can be set to an integer, or to
the string 'EOF'.

=item $unit->adjust_lines

This will check all child unit bounds, if they fall outside the parents bounds
then the parent will be adjusted.

=item $ar = $unit->post

=item $ar = $unit->modify

=item $ar = $unit->buildup

=item $ar = $unit->teardown

Access to the arrayrefs for the specific child types.

=item $code_or_ar = $unit->primary

Get the primary, which may be an arrayref of other units, or a single coderef.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
