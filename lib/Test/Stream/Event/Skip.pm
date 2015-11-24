package Test::Stream::Event::Skip;
use strict;
use warnings;

use base 'Test::Stream::Event::Ok';
use Test::Stream::HashBase accessors => [qw/reason/];

sub init {
    my $self = shift;
    $self->SUPER::init;

    $self->{+PASS} = 0;
    $self->{+EFFECTIVE_PASS} = 1;
}

sub update_state { $_[1]->bump(1) }

sub causes_fail { 0 }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Skip - Skip event type

=head1 DESCRIPTION

Skip events bump test counts just like L<Test::Stream::Event::Ok> events, but
they can never fail.

=head1 SYNOPSIS

    use Test::Stream::Context qw/context/;
    use Test::Stream::Event::Skip;

    my $ctx = context();
    my $event = $ctx->skip($name, $reason);

or:

    my $ctx   = debug();
    my $event = $ctx->send_event(
        'Skip',
        name   => $name,
        reason => $reason,
    );

=head1 ACCESSORS

=over 4

=item $reason = $e->reason

The original true/false value of whatever was passed into the event (but
reduced down to 1 or 0).

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
