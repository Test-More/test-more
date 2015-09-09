package Test::Stream::Event::Diag;
use strict;
use warnings;

use Test::Stream::Event(
    accessors => [qw/message/],
);

use Carp qw/confess/;

use Test::Stream::Formatter::TAP qw/OUT_TODO OUT_ERR/;

sub init {
    $_[0]->SUPER::init();
    if (defined $_[0]->{+MESSAGE}) {
        $_[0]->{+MESSAGE} .= "";
    }
    else {
        $_[0]->{+MESSAGE} = 'undef';
    }
}

sub to_tap {
    my $self = shift;

    my $msg = $self->{+MESSAGE};
    return unless $msg;

    $msg = "# $msg" unless $msg eq "\n";

    chomp($msg);
    $msg =~ s/\n/\n# /g;

    return [
        ($self->{+DEBUG}->no_diag ? OUT_TODO : OUT_ERR),
        "$msg\n",
    ];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Diag - Diag event type

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

Diagnostics messages, typically rendered to STDERR.

=head1 SYNOPSIS

    use Test::Stream::Context qw/context/;
    use Test::Stream::Event::Diag;

    my $ctx = context();
    my $event = $ctx->diag($message);

=head1 ACCESSORS

=over 4

=item $diag->message

The message for the diag.

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
