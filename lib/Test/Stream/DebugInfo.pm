package Test::Stream::DebugInfo;
use strict;
use warnings;

use Test::Stream::Threads;

use Test::Stream::Carp qw/confess/;

use Test::Stream::HashBase(
    accessors => [qw/frame todo skip detail pid tid/],
);

sub init {
    confess "Frame is required"
        unless $_[0]->{+FRAME};

    $_[0]->{+PID} ||= $$;
    $_[0]->{+TID} ||= get_tid();
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
    warn $msg . ' ' . $self->trace . "\n";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;
    die $msg . ' ' . $self->trace . "\n";
}

sub call { @{$_[0]->{+FRAME}} }

sub package { $_[0]->{+FRAME}->[0] }
sub file    { $_[0]->{+FRAME}->[1] }
sub line    { $_[0]->{+FRAME}->[2] }
sub subname { $_[0]->{+FRAME}->[3] }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DebugInfo - Debug information for events

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
