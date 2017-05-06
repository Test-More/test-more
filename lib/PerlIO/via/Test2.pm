package PerlIO::via::Test2;
use strict;
use warnings;

use Test2::Util::HashBase qw/-stream_name diagnostics no_event/;

use Carp qw/croak/;

our %PARAMS;
my %STREAMS;

sub get_stream {
    my $class = shift;
    my ($name) = @_;

    return $STREAMS{$name};
}

sub PUSHED {
    my $class = shift;

    my $name = $PARAMS{stream_name}
        or croak 'No "stream_name" found in %PARAMS hash';

    croak "Stream '$name' already defined"
        if $STREAMS{$name};

    $STREAMS{$name} = bless {%PARAMS}, $class;

    # Be Safe...er
    %PARAMS = ();

    return $STREAMS{$name};
}

sub WRITE {
    my ($self, $buffer, $handle) = @_;

    # Test2::API not loaded (?)
    if ($self->{+NO_EVENT} || !$INC{'Test2/API.pm'}) {
        print $handle $buffer;
        return length($buffer);
    }

    my ($ok, $error, $sent);
    {
        local ($@, $?, $!);
        $ok = eval {
            local $self->{+NO_EVENT} = 1;
            my $ctx = Test2::API::context(level => 1);
            $ctx->send_event('Output' => %$self, message => $buffer);
            $sent = 1;
            $ctx->release;

            1;
        };
        $error = $@;
    }
    return length($buffer) if $ok;

    # Make sure we see the output
    print $handle $buffer unless $sent;

    # Prevent any infinite loops
    local $self->{+NO_EVENT} = 1;
    die $error;

    # In case of __DIE__ handler?
    return length($buffer);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

PerlIO::via::Test2 - PerlIO layer for turning output into events.

=head1 *EXPERIMENTAL*

Please note that this is currently considered experimental and may be removed
in the future.

=head1 SYNOPSIS

    use PerlIO::via::Test2;

    local %PerlIO::via::Test2::PARAMS = (
        %params,
        stream_name => 'my stream',
        diagnostics => 0,
    );

    binmode($handle, ':via(Test2)') or die "Could not add Test2 PerlIO Layer: $!";

    print $handle "This will be an event!";

=head1 DESCRIPTION

This PerlIO layer makes events out of all data written to it. So long as the
formatter you are using has its own duplicates of STDERR and STDOUT it is safe
to apply this to STDOUT or STDERR if you want all prints and warnings to become
events instead of regular output.

=head1 ATTRIBUTES

=over 4

=item stream_name => $string

Name of the stream (whatever you want, but must be unique).

=item diagnostics => $bool

If this is true then C<diagnostics> will be set to true on the
L<Test2::Event::Output> events generated. This effectively is a switch for the
formatter to know if the event should be rendered to STDOUT or STDERR for
formatters that use both.

=back

=head1 CONTROL VARIABLES

=over 4

=item %PerlIO::via::Test2::PARAMS

You B<MUST> set this before applying the perlio layer, this is how construction
arguments are passed in. At the minimum you must specify the C<'stream_name'>
key.

It is recommended that you use C<local> to set this so that you do not bleed
into other code's parameters.

=back

=head1 SEE ALSO

See L<Test2::API> which has the C<event_stream()> function that is a
higher-level interface to the perlio layer stuff.

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

