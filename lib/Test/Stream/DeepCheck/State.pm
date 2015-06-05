package Test::Stream::DeepCheck::State;
use strict;
use warnings;

use List::Util qw/max/;

use Test::Stream::DeepCheck::Util qw/render_var/;

use Test::Stream::HashBase(
    accessors => [qw/path diag strict debug check_diag error seen/],
);

sub init {
    $_[0]->{+PATH} = [];
    $_[0]->{+DIAG} = [];
    $_[0]->{+SEEN} = {};
}

sub render_diag {
    my $self = shift;

    my $path = '$_';
    my @parts = @{$self->{+PATH}};
    while (my $part = shift @parts) {
        last unless @parts;
        my $child = shift @parts;
        $path = $part->path($path, $child);
    }

    my $maxnum = max map { $_->[1] } @{$self->diag};
    my $numlen = length("$maxnum");

    my @lines;
    my $cfile = "";
    my $cline = -1;
    my $space = 0;
    my $lcount = -1;
    for my $diag (reverse @{$self->diag}) {
        my ($file, $line, $msg) = @$diag;
        if ($cfile ne $file) {
            push @lines => $file;
            $cfile = $file;
            $cline = -1;
        }

        my $print_line;
        if ($cline == $line) {
            $print_line = '-' x length($line);
        }
        else {
            $print_line = $line;
            $cline = $line;
            $lcount++;
        }

        push @lines => sprintf("%${numlen}s %s%s", $print_line, ' ' x (2 * $space++), $msg);
    }

    my $check = $self->check_diag;
    my $err = $self->error;
    chomp($err) if $err;

    return join("\n",
        "Path: $path",
        ($err ? "Caught Exception: $err" : "Failed Check: $check"),
        ($lcount > 0 ? @lines : ())
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::State - Tracks and manages state on deep and/or
recursive structure tests.

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

This package is used to track the state when running deep comparisons of data
structures.

=head1 METHODS

=over 4

=item $diag = $state->render_diag()

This uses all the stored state to produce the most helpful diagnostics message
it can. This diagnostic message will have the path into the structure
C<< $_->{foo}->[5]->{bar} >>. It will also have the filename and line number
where any failed check occurred. If extra debug info is available it may also
print out a line-by-line of where the structure was defined.

=item $arrayref = $state->path

This is a stack of Test::Stream::DeepCheck::* objects that tells us where we
are in the check. An item pushes itself to this stack before recursing into
more checks, it pops it when it is done.

=item $arrayref = $state->diag

When a check fails it adds some diagnostics information to this arrayref. Diag
info should be arrayrefs with the file, the line, and the message of the
diagnostic. This information is only used if there is enough of it to be
useful, that is that if everything reports the same file and line number it is
not displayed.

=item $bool = $state->strict

If this is true then strict checking is enabled. Strict checkingmeans all
elements and keys must be accounted for on both sides of the check. It also
turns off coderef checks and regex checks requiring them to pass an '=='
instead of running them or using '=~'.

=item $state->set_check_diag($string)

=item $string = $state->check_diag

This should be the message from the check that triggered the failure, in other
words the first point of failure.

=item $err = $state->error

This will be set if the first point of failure was a thrown exception.

=item $hashref = $state->seen

This is used when recursing to ensure we do not have an infinite recustion
problem.

=item $dbg = $state->debug

File+Line info for the state. This will be an L<Test::Stream::DebugInfo>
object.

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
