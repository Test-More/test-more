package Test::Stream::Hub;
use strict;
use warnings;

use Test::Stream::State;

use Test::Stream::HashBase(
    accessors => [qw{
        state
        _formatter
    }],
);

sub init {
    my $self = shift;

    $self->{+STATE} ||= Test::Stream::State->new;

    if (my $formatter = delete $self->{formatter}) {
        $self->format($formatter);
    }
}

sub format {
    my $self = shift;

    my $old = $self->{+_FORMATTER};
    ($self->{+_FORMATTER}) = @_ if @_;

    return $old;
}

sub send {
    my $self = shift;
    my ($e) = @_;

    my $state = $self->{+STATE};
    $e->update_state($state);
    my $count = $state->count;

    $self->{+_FORMATTER}->write($e, $count) if $self->{+_FORMATTER};

    my $code = $e->terminate;
    $self->terminate($code, $e) if defined $code;

    return $e;
}

sub terminate {
    my $self = shift;
    my ($code) = @_;
    CORE::exit($code);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Hub - The conduit through which all events flow.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 SYNOPSIS

    use Test::Stream::Hub;

    my $hub = Test::Stream::Hub->new();
    $hub->send(...);

=head1 DESCRIPTION

The hub is the place where all events get processed and handed off to the
formatter. The hub also tracks test state, and provides everal hooks into the
event pipeline.

=head1 COMMON TASKS

=head2 SENDING EVENTS

    $hub->send($event)

The C<send()> method is used to issue an event to the hub. This method will
handle thread/fork sych, mungers, listeners, TAP output, etc.

=head2 SETTING THE FORMATTER

By default an instance of L<Test::Stream::TAP> is created and used.

    my $old = $hub->format(My::Formatter->new);

Setting the formatter will REPLACE any existing formatter. You may set the
formatter to undef to prevent output. The old formatter will be returned if one
was already set. Only 1 formatter is allowed at a time.

=head1 METHODS

=over 4

=item $hub->send($event)

This is where all events enter the hub for processing.

=item $old = $hub->format($formatter)

Replace the existing formatter instance with a new one. Formatters must be
objects that implement a C<< $formatter->write($event) >> method.

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
