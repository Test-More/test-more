package Test2::Event::Output;
use strict;
use warnings;

use Carp qw/croak/;

our $VERSION = '1.302084';

BEGIN { require Test2::Event; our @ISA = qw(Test2::Event) }
use Test2::Util::HashBase qw/-stream_name -message -diagnostics/;

sub init {
    croak "'stream_name' is required"
        unless $_[0]->{+STREAM_NAME};

    $_[0]->{+MESSAGE} = 'undef' unless defined $_[0]->{+MESSAGE};
}

sub summary { $_[0]->{+MESSAGE} }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Event::Output - Events that represent data printed to a filehandle.

=head1 DESCRIPTION

This is used when output sent to a handle is turned into an event instead of
being actually printed.

=head1 SYNOPSIS

    use Test2::API qw/context/;
    use Test2::Event::Output;

    my $ctx = context();
    my $event = $ctx->send_event('Output', stream_name => 'foo', message => "hello world\n");
    $ctx->release;

=head1 ACCESSORS

=over 4

=item $name = $event->stream_name

Name of the stream that produced the event

=item my $msg = $event->message

The data that was printed.

=item $event->diagnostics

True if the message is diagnostics in nature. Some formatters use this as a
flag to redirect output to STDERR instead of STDOUT.

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2017 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
