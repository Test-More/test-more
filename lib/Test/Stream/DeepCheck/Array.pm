package Test::Stream::DeepCheck::Array;
use strict;
use warnings;

use Scalar::Util qw/reftype/;
use Carp qw/confess/;

use Test::Stream::DeepCheck::Util qw/render_var/;
use Test::Stream::Util qw/try/;

use Test::Stream::Block;

use Test::Stream::DeepCheck::Meta;
use Test::Stream::HashBase(
    base => 'Test::Stream::DeepCheck::Meta',
    accessors => [qw/elements ended/],
);

sub init {
    $_[0]->SUPER::init();
    $_[0]->{+ELEMENTS} = [];
}

sub add_element {
    my $self = shift;
    my ($item) = @_;

    confess "End of array already set, cannot add more elements"
        if $self->{+ENDED};

    confess "item is required, and must be a reference"
        unless $item && ref $item;

    confess "$item is not a supported item"
        unless $item->isa('Test::Stream::DeepCheck::Check')
            || $item->isa('Test::Stream::DeepCheck::Meta');

    push @{$self->{+ELEMENTS}} => $item;

    return unless $self->{+_BUILDER} && $item->_builder;
    return if @{$self->{+ELEMENTS}} > 1;

    $self->{+DEBUG}->frame->[2] = $item->debug->line - 1
        if  $item->debug->line < $self->{+DEBUG}->line;
}

sub end {
    my $self = shift;
    my $call = shift || [caller];

    push @{$self->{+ELEMENTS}} => $call;
    $self->{+ENDED} = $call;

    return unless $self->{+_BUILDER};
    return if @{$self->{+ELEMENTS}} > 1;

    $self->{+DEBUG}->frame->[2] = $call->[2] - 1
        if $call->[2] < $self->{+DEBUG}->line;
}

sub filter {
    my $self = shift;
    my ($code, $call) = @_;
    $call ||= [caller];

    push @{$self->{+ELEMENTS}} => $code;

    return unless $self->{+_BUILDER};
    return if @{$self->{+ELEMENTS}} > 1;

    my $block = Test::Stream::Block->new(caller => $call, coderef => $code);
    my $file = $block->file;
    return if $file ne $self->{+DEBUG}->frame->[1];

    my $line = $block->start_line;
    $self->{+DEBUG}->frame->[2] = $line - 1
        if $line < $self->{+DEBUG}->line;
}

sub path {
    my $self = shift;
    my ($parent_path, $child) = @_;

    $child = render_var($child);

    return "$parent_path\->[$child]";
}

sub update_diag {
    my $self   = shift;
    my %params = @_;

    my $state = $params{state};
    my $idx   = $params{index};
    my $check = $params{check};
    my $val   = $params{val};
    my $err   = $params{error};

    my $mdbg = $self->{+DEBUG};
    my $ourline = [ $mdbg->file, $mdbg->line, '[' ];

    if (!$check || reftype($check) eq 'ARRAY') {
        my $msg = "Expected end of array, got " . render_var($val);
        my @frame = $check ? ($check->[1], $check->[2]) : ($mdbg->file, $mdbg->line);
        push @{$state->diag} => [ @frame, "$idx: $msg" ];
        $state->set_check_diag($msg);
    }
    elsif ($check->isa('Test::Stream::DeepCheck::Check')) {
        my $cdiag = $check->diag($val);
        $state->set_check_diag($cdiag);
        my $cdbg = $check->debug;
        push @{$state->diag} => [ $cdbg->file, $cdbg->line, "$idx: $cdiag" ];
    }
    elsif ($check->isa('Test::Stream::DeepCheck::Meta') && !$err) {
        # Modify the diag it already inserted
        $state->diag->[-1]->[2] = "$idx: " . $state->diag->[-1]->[2];
    }

    push @{$state->diag} => $ourline;
}

sub verify_array {
    my $self = shift;
    my ($got, $state) = @_;

    if (!$got) {
        my $mdbg = $self->{+DEBUG};
        $state->set_check_diag("reftype(undef) eq 'ARRAY'");
        push @{$state->diag} => [ $mdbg->file, $mdbg->line, "Expected an 'ARRAY' reference, but got undef." ];
        return 0;
    }

    my $type = reftype($got) || 'NOT A REFERENCE';
    if ($type ne 'ARRAY') {
        my $mdbg = $self->{+DEBUG};
        $state->set_check_diag("reftype(" . render_var($got) . ") eq 'ARRAY'");
        push @{$state->diag} => [ $mdbg->file, $mdbg->line, "Expected an 'ARRAY' reference, but got '$type'." ];
        return 0;
    }

    my $elements = $self->{+ELEMENTS};

    $got = [@$got]; # Clone the array so we can modify it.


    my $idx = -1;
    my $end = undef;
    for my $check (@$elements) {
        if (reftype($check) eq 'ARRAY') {
            next unless @$got;
            $end = $check;
            last;
        }

        if (reftype($check) eq 'CODE') {
            $got = [$check->(@$got)];
            next;
        }

        my $val = shift @$got;
        push @{$state->path} => ++$idx;

        my $bool;
        my ($ok, $err) = try { $bool = $check->verify($val, $state) };

        if ($bool && $ok) {
            pop @{$state->path};
            next;
        }

        $state->set_error($err) unless $ok;
        $self->update_diag(state => $state, index => $idx, check => $check, val => $val, error => $err);
        return 0;
    }

    if (@$got && ($end || $state->strict)) {
        push @{$state->path} => ($idx + 1);
        $self->update_diag(state => $state, index => $idx, check => $end, val => $got->[0]);
        return 0;
    }

    return 1;
}

sub verify {
    my $self = shift;
    my ($got, $state) = @_;

    # if it already failed we would not be here
    # if it already passed returning 1 is fine
    # if it is recursive then it has been true so far, return true, other
    # checks will catch any failures.
    return 1 if $state->seen->{$self}->{$got}++;

    $self->verify_meta(@_) || return 0;

    push @{$state->path} => $self;
    $self->verify_array(@_) || return 0;
    pop @{$state->path};

    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Array - Class for doing deep array checks

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This package represents a deep check of an array datastructure.

=head1 SUBCLASSES

This class subclasses L<Test::Stream::DeepCheck::Meta>.

=head1 METHODS

=over 4

=item $array->add_element($check)

Add an element to the array check. The check should be an instance of
L<Test::Stream::DeepCheck::Check>.

=item $array->end

=item $array->end(\@call)

Mark the end of the array, no elements should exist beyond this point.

=item $array->filter(sub { ... })

=item $array->filter(sub { ... }, \@call)

Add a filter sub that will be used to modify the list of elements left to
check.

=item $array->verify_array($got, $state)

Used to verify an array against the checks.

=item $array->verify($got, $state)

Used to verify an array against the checks and meta-checks.

=item $dbg = $array->debug

File+Line info for the state. This will be an L<Test::Stream::DebugInfo>
object.

=item $array->path($parent, $child)

Used internally, not intended for outside use.

=item $array->update_diag

Used internally, not intended for outside use.

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
