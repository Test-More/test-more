package Test::Stream::Event::Bail;
use strict;
use warnings;

use Test::Stream::TAP qw/OUT_STD/;

use Test::Stream::Event(
    accessors => [qw/reason quiet/],
);

sub to_tap {
    my $self = shift;
    return if $self->{+QUIET};
    return [
        OUT_STD,
        "Bail out!  " . $self->reason . "\n",
    ];
}

sub update_state {
    my $self = shift;
    my ($state) = @_;

    $state->bump_fail;
}

# Make sure the tests terminate
sub terminate { 255 };

sub global { 1 };

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Bail - Bailout!

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

The bailout event is generated when things go horribly wrong and you need to
halt all testing in the current file.

=head1 SYNOPSIS

    use Test::Stream::Context qw/context/;
    use Test::Stream::Event::Bail;

    my $ctx = context();
    my $event = $ctx->bail('Stuff is broken');

=head1 METHODS

Inherits from L<Test::Stream::Event>. Also defines:

=over 4

=item $reason = $e->reason

The reason for the bailout.

=item $bool = quiet

Should the bailout be quiet?

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
