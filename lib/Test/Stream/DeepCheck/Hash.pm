package Test::Stream::DeepCheck::Hash;
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
    accessors => [qw/fields ended/],
);

sub init {
    $_[0]->SUPER::init();
    $_[0]->{+FIELDS} = [];
}

sub add_field {
    my $self = shift;
    my ($key, $check) = @_;

    confess "End of fields already set, cannot add more fields"
        if $self->{+ENDED};

    confess "key is required" unless $key;
    confess "check is required" unless $check;

    confess "Check must either be a 'Test::Stream::DeepCheck::Check' or 'Test::Stream::DeepCheck::Meta' object"
        unless $check->isa('Test::Stream::DeepCheck::Check')
            || $check->isa('Test::Stream::DeepCheck::Meta');

    push @{$self->{+FIELDS}} => [$key, $check];

    return unless $self->{+_BUILDER} && $check->_builder;
    return if @{$self->{+FIELDS}} > 1;

    $self->{+DEBUG}->frame->[2] = $check->debug->line - 1
        if $check->debug->line < $self->{+DEBUG}->line;
}

sub end {
    my $self = shift;
    my $call = shift || [caller];

    push @{$self->{+FIELDS}} => [$call];
    $self->{+ENDED} = $call;

    return unless $self->{+_BUILDER};
    return if @{$self->{+FIELDS}} > 1;

    $self->{+DEBUG}->frame->[2] = $call->[2] - 1
        if $call->[2] < $self->{+DEBUG}->line;
}

sub filter {
    my $self = shift;
    my ($code, $call) = @_;
    $call ||= [caller];

    push @{$self->{+FIELDS}} => [$code];

    return unless $self->{+_BUILDER};
    return if @{$self->{+FIELDS}} > 1;

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

    $child = render_var($child) unless $child =~ m/, /;

    return "$parent_path\->{$child}";
}

sub update_diag {
    my $self = shift;
    my %params = @_;

    my $state = $params{state};
    my $check = $params{check};
    my $key   = $params{key};
    my $val   = $params{val};
    my $err   = $params{error};

    my $mdbg = $self->{+DEBUG};
    my $ourline = [ $mdbg->file, $mdbg->line, '{' ];
    my $rkey = render_var($key);

    if (!$check || reftype($check) eq 'ARRAY') {
        my $msg = "Expected no more fields, got $val";
        my @frame = $check ? ($check->[1], $check->[2]) : ($mdbg->file, $mdbg->line);
        push @{$state->diag} => [ @frame, $val ];
        $state->set_check_diag($msg);
    }
    elsif ($check->isa('Test::Stream::DeepCheck::Check')) {
        my $cdiag = $check->diag($val);
        $state->set_check_diag($cdiag);
        my $cdbg = $check->debug;
        push @{$state->diag} => [ $cdbg->file, $cdbg->line, "$rkey: $cdiag" ];
    }
    elsif ($check->isa('Test::Stream::DeepCheck::Meta') && !$err) {
        # Modify the diag it already inserted
        $state->diag->[-1]->[2] = "$rkey: " . $state->diag->[-1]->[2];
    }

    push @{$state->diag} => $ourline;
}

sub verify_hash {
    my $self = shift;
    my ($got, $state) = @_;

    if (!$got) {
        my $mdbg = $self->{+DEBUG};
        $state->set_check_diag("reftype(undef) eq 'HASH'");
        push @{$state->diag} => [ $mdbg->file, $mdbg->line, "Expected a 'HASH' reference, but got undef." ];
        return 0;
    }

    my $type = reftype($got) || 'NOT A REFERENCE';
    if ($type ne 'HASH') {
        my $mdbg = $self->{+DEBUG};
        $state->set_check_diag("reftype(" . render_var($got) . ") eq 'HASH'");
        push @{$state->diag} => [ $mdbg->file, $mdbg->line, "Expected a 'HASH' reference, but got '$type'." ];
        return 0;
    }

    my $fields = $self->{+FIELDS};

    $got = {%$got}; # Clone the hash so we can modify it.

    my $end = undef;
    for my $field (@$fields) {
        my ($key, $check) = @$field;

        if (ref $key) {
            if (reftype($key) eq 'ARRAY') {
                next unless keys %$got;
                $end = $key;
                last;
            }

            if (reftype($key) eq 'CODE') {
                $got = {$key->(%$got)};
                next;
            }
        }

        my $val = delete $got->{$key};

        push @{$state->path} => $key;

        my $bool;
        my ($ok, $err) = try { $bool = $check->verify($val, $state) };

        if ($bool && $ok) {
            pop @{$state->path};
            next;
        }

        $state->set_error($err) unless $ok;
        $self->update_diag(state => $state, check => $check, key => $key, val => $val, error => $err);
        return 0;
    }

    if (keys(%$got) && ($end || $state->strict)) {
        my @bad = sort keys %$got;
        if (@bad > 1) {
            my $keys = join ", ", map { render_var($_, 1) } sort keys %$got;
            push @{$state->path} => $keys;
            $self->update_diag(state => $state, val => $keys);
        }
        else {
            push @{$state->path} => $bad[0];
            $self->update_diag(state => $state, val => render_var($bad[0], 1));
        }
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
    $self->verify_hash(@_) || return 0;
    pop @{$state->path};

    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Hash - Class for doing deep hash checks

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

This package represents a deep check of an hash datastructure.

=head1 SUBCLASSES

This class subclasses L<Test::Stream::DeepCheck::Meta>.

=head1 METHODS

=over 4

=item $hash->add_field($key, $check)

Add an element to the hash check. The check should be an instance of
L<Test::Stream::DeepCheck::Check>.

=item $hash->end

=item $hash->end(\@call)

Mark the end of the hash, no elements should exist beyond this point.

=item $hash->filter(sub { ... })

=item $hash->filter(sub { ... }, \@call)

Add a filter sub that will be used to modify the list of elements left to
check.

=item $hash->verify_hash($got, $state)

Used to verify an hash against the checks.

=item $hash->verify($got, $state)

Used to verify an hash against the checks and meta-checks.

=item $dbg = $hash->debug

File+Line info for the state. This will be an L<Test::Stream::DebugInfo>
object.

=item $hash->path($parent, $child)

Used internally, not intended for outside use.

=item $hash->update_diag

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
