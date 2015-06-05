package Test::Stream::DeepCheck::Meta;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Carp qw/confess/;

use Test::Stream::Util qw/try/;

use Test::Stream::HashBase(
    accessors => [qw/meta debug _builder/],
);

sub init {
    confess "the debug attribute is required"
        unless $_[0]->{+DEBUG};

    $_[0]->{+META} = [];
}

sub add_meta {
    my $self = shift;
    my ($name, $check) = @_;

    confess "Only 'Test::Stream::DeepCheck::Check' objects may be added as meta checks"
        unless $check && $check->isa('Test::Stream::DeepCheck::Check');

    push @{$self->{+META}} => [$name, $check];

    return unless $self->{+_BUILDER} && $check->_builder;
    return if @{$self->{+META}} > 1;

    $self->{+DEBUG}->frame->[2] = $check->debug->line - 1
        if $check->debug->line < $self->{+DEBUG}->line;
}

sub verify_meta {
    my $self = shift;
    my ($got, $state) = @_;

    my $meta = $self->{+META};
    return 1 unless @$meta;

    for my $set (@$meta) {
        my ($name, $check) = @$set;
        my $bool;
        my ($ok, $err) = try { $bool = $check->verify($got, $state) };
        next if $ok && $bool;

        $state->set_error($err) unless $ok;

        my $cdiag = $check->diag($got);
        my $cdbg  = $check->debug;

        $state->set_check_diag($cdiag);

        push @{$state->diag} => [ $cdbg->file, $cdbg->line, "($name) $cdiag" ];

        return 0;
    }

    return 1;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Meta - Base class for deep structure checks.

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

This package lets you add meta-checks against a datastructure (what type it is,
etc). This is used in addition to structure specific tests such as array
elements, hash fields, object methods, etc.

=head1 METHODS

=over 4

=item $meta->add_meta($name, $check)

Add a meta check, the name is used for debugging, the check should be an
instance of L<Test::Stream::DeepCheck::Check>.

=item $meta->verify_meta($got, $state)

Run the checks against C<$got> using the provided
C<Test::Stream::DeepCheck::State> object to track things.

=item $arrayref = $meta->meta

Get the arrayref of meta-checks

=item $dbg = $meta->debug

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
