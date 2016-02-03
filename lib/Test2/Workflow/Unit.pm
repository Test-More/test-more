package Test2::Workflow::Unit;
use strict;
use warnings;

use Test2::Todo();
use Test2::API qw/test2_stack/;
use Test2::API::Context();
use Test2::Util::Trace();

use Carp qw/confess croak/;
use Scalar::Util qw/reftype/;

use Test2::Util::HashBase qw{
    name meta type wrap stash
    package file start_line end_line
    post
    modify
    buildup
    primary
    teardown
    is_root
    filtered
    _filtered
};

sub init {
    $_[0]->{+META} ||= {};

    for (NAME, PACKAGE, FILE, START_LINE, END_LINE) {
        confess "$_ is a required attribute" unless defined $_[0]->{$_}
    }

    $_[0]->{+STASH} ||= {};
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

sub children {
    my $self = shift;
    return map { my $x = $self->$_; ref($x) eq 'ARRAY' ? @$x : () } MODIFY(), BUILDUP(), PRIMARY(), TEARDOWN();
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

sub trace {
    my $self = shift;

    my $hub = test2_stack()->top;

    return Test2::Util::Trace->new(
        frame  => [@$self{qw/package file start_line name/}],
        detail => "in block '$self->{+NAME}' defined in $self->{+FILE} (Approx) lines $self->{+START_LINE} -> $self->{+END_LINE}",
    );
}

sub context {
    my $self = shift;

    my $stack = test2_stack();
    my $hub   = $stack->top;

    my $todo = $self->meta->{todo};
    $todo = Test2::Todo->new(reason => $todo) if defined($todo);

    my $trace = $self->trace;

    my $ctx = Test2::API::Context->new(
        stack => $stack,
        hub   => $hub,
        trace => $trace,
    );

    # Stash the todo in the context so that it goes away with the context
    $ctx->meta(__PACKAGE__, {})->{todo} = $todo;

    return $ctx;
}

sub filter {
    my $self = shift;
    my ($file, $line, $name) = @_;

    croak "At least 1 defined argument must be passed to filter()"
        unless defined($file) || defined($line) || defined($name);

    # Already filtered, no need to do it again
    return $self->{+_FILTERED} ? 0 : 1 if defined $self->{+_FILTERED};

    # Need to do a depth-first search, this will populate the 'filtered' key on
    # all child units. This is important!
    my $keep;
    my $from_modify = 0;
    for my $attr ( PRIMARY(), MODIFY(), BUILDUP(), TEARDOWN() ) {
        next unless grep { $_->filter($file, $line, $name) }
                    map  { @{$_} }
                    grep {$_ && ref($_) eq 'ARRAY'}
                    $self->$attr;

        $keep = 1;
        $from_modify = 1 if $attr eq MODIFY();
    }

    if($from_modify) {
        # One of our modifiers is a keeper, we need to unfilter everything but
        # our modifiers.
        $_->_unfilter for
            map  { @{$_} }
            grep {$_ && ref($_) eq 'ARRAY'}
            map  { $self->$_ }
            PRIMARY(), BUILDUP(), TEARDOWN();
    }
    elsif($keep) {
        # One of our children is a keeper, we need to unfilter everything but
        # our primaries.
        $_->_unfilter for
            map  { @{$_} }
            grep {$_ && ref($_) eq 'ARRAY'}
            map  { $self->$_ }
            MODIFY(), BUILDUP(), TEARDOWN();
    }
    else {
        # If no children were keepers then we check if we are a keeper.
        $keep = 1;
        $keep &&= $file eq $self->{+FILE} if defined $file;
        $keep &&= $name eq $self->{+NAME} if defined $name;
        if (defined $line) {
            $keep &&= $line >= $self->{+START_LINE};
            $keep &&= $self->{+END_LINE} ne 'EOF';
            $keep &&= $line <= $self->{+END_LINE};
        }

        # We are a keeper, unfilter everything under us
        $self->_unfilter if $keep;
    }

    # Give us the mark
    $self->{+_FILTERED} = $keep ? 0 : 1;
    $self->{+FILTERED}  = $keep ? 0 : 1 unless defined $self->{+FILTERED};

    return $keep;
}

sub _unfilter {
    my $self = shift;

    $self->{+FILTERED} = 0;

    $_->_unfilter for
        map  { @{$_} }
        grep {$_ && ref($_) eq 'ARRAY'}
        map  { $self->$_ }
        PRIMARY(), MODIFY(), BUILDUP(), TEARDOWN();
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Workflow::Unit - Representation of a workflow unit.

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

This package is a single unit of work to be done in a workflow. The unit may
contain a codeblock, or many child units.

=head1 METHODS

=over 4

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

Generate an L<Test2::Debug> object for this unit.

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

=item $check = $unit->filtered

C<$check> will be undefined when there is no filter.

C<$check> will be true if the unit has been filtered out. (Should not run)

C<$check> will be 0 if the unit passed the filter. (Should run).

This means that a false result is interpreted as RUN, and a true result is
interpreted as DO NOT RUN.

=item $keep = $unit->filter($file, $line, $name)

This is used to filter out units that DO NOT match the input. All 3 arguments
are optional, filtering will only consider the ones that are provided. Use
undef for an argument to ignore it.

This will set the C<filtered> attribute on the unit and all descendant units.
The attribute will be set to C<1> or C<0> depending on if the unit should run
given the filter.

This will return true if the unit or one of its descendants matched the filter.
It will return false if there are no matches.

If C<filter()> has already run then it will return the result of its last run
without even looking at the input parameters. This means you can only ever run
filter once on any unit tree.

=item $unit->unfilter()

This will set the C<filtered> attribute to C<0> on the unit and all its
descendednts.

=back

=head1 SOURCE

The source code repository for Test2-Workflow can be found at
F<http://github.com/Test-More/Test2-Workflow/>.

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
