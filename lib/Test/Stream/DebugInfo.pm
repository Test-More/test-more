package Test::Stream::DebugInfo;
use strict;
use warnings;

use Test::Stream::Util qw/get_tid/;

use Carp qw/confess carp/;

use Test::Stream::HashBase(
    accessors => [qw/frame detail pid tid skip todo parent_todo/],
);

BEGIN {
    for my $attr (SKIP, TODO, PARENT_TODO) {
        my $set = __PACKAGE__->can("set_$attr");
        my $get = __PACKAGE__->can($attr);

        my $new_set = sub {
            carp "Use of '$attr' attribute for DebugInfo is deprecated";
            $set->(@_);
        };

        my $new_get = sub {
            carp "Use of '$attr' attribute for DebugInfo is deprecated";
            $get->(@_);
        };

        no strict 'refs';
        no warnings 'redefine';
        *{"set_$attr"}  = $new_set;
        *{"$attr"}      = $new_get;
        *{"_$attr"}     = $get;
        *{"_set_$attr"} = $set;
    }
}

sub init {
    confess "Frame is required"
        unless $_[0]->{+FRAME};

    $_[0]->{+PID} ||= $$;
    $_[0]->{+TID} ||= get_tid();

    for my $attr (SKIP, TODO, PARENT_TODO) {
        next unless defined $_[0]->{$attr};
        $_[0]->alert("Use of '$attr' attribute for DebugInfo is deprecated")
    }
}

sub snapshot { bless {%{$_[0]}}, __PACKAGE__ };

sub trace {
    my $self = shift;
    return $self->{+DETAIL} if $self->{+DETAIL};
    my ($pkg, $file, $line) = $self->call;
    return "at $file line $line";
}

sub alert {
    my $self = shift;
    my ($msg) = @_;
    warn $msg . ' ' . $self->trace . ".\n";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;
    die $msg . ' ' . $self->trace . ".\n";
}

sub call { @{$_[0]->{+FRAME}} }

sub package { $_[0]->{+FRAME}->[0] }
sub file    { $_[0]->{+FRAME}->[1] }
sub line    { $_[0]->{+FRAME}->[2] }
sub subname { $_[0]->{+FRAME}->[3] }

sub no_diag {
    my $self = shift;
    $self->alert("Use of the 'no_diag' method is deprecated");
    $self->_no_diag(@_);
}

sub no_fail {
    my $self = shift;
    $self->alert("Use of the 'no_fail' method is deprecated");
    $self->_no_fail(@_);
}

sub _no_diag {
    my $self = shift;
    return defined($self->{+TODO})
        || defined($self->{+SKIP})
        || defined($self->{+PARENT_TODO});
}

sub _no_fail {
    my $self = shift;
    return defined($self->{+TODO})
        || defined($self->{+SKIP});
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DebugInfo - Debug information for events

=head1 DESCRIPTION

All events need to have access to information about where they were created, as
well as if they are todo, or part of a skipped test. This object represents
that information.

=head1 SYNOPSIS

    use Test::Stream::DebugInfo;

    my $dbg = Test::Stream::DebugInfo->new(
        frame => [$package, $file, $line, $subname],
    );

=head1 METHODS

=over 4

=item $dbg->set_todo($reason)

=item $reason = $dbg->todo

Get/Set/Unset todo for the current debug-info.

=item $dbg->set_skip($reason)

=item $reason = $dbg->skip

Get/Set/Unset skip for the current debug-info.

=item $dbg->set_detail($msg)

=item $msg = $dbg->detail

Used to get/set a custom trace message that will be used INSTEAD of
C<< at <FILE> line <LINE> >> when calling C<< $dbg->trace >>.

=item $dbg->trace

Typically returns the string C<< at <FILE> line <LINE> >>. If C<detail> is set
then its value wil be returned instead.

=item $dbg->alert($MESSAGE)

This issues a warning at the frame (filename and line number where
errors should be reported).

=item $dbg->throw($MESSAGE)

This throws an exception at the frame (filename and line number where
errors should be reported).

=item $frame = $dbg->frame()

Get the call frame arrayref.

=item ($package, $file, $line, $subname) = $dbg->call()

Get the caller details for the debug-info. This is where errors should be
reported.

=item $pkg = $dbg->package

Get the debug-info package.

=item $file = $dbg->file

Get the debug-info filename.

=item $line = $dbg->line

Get the debug-info line number.

=item $subname = $dbg->subname

Get the debug-info subroutine name.

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
