package Test::Stream::Event::Ok;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Carp qw/confess/;

use Test::Stream::TAP qw/OUT_STD/;

use Test::Stream::Event::Diag;

use Test::Stream::Event(
    accessors => [qw/pass effective_pass name diag/],
);

sub init {
    my $self = shift;

    $self->SUPER::init();

    # Do not store objects here, only true/false/undef
    if ($self->{+PASS}) {
        $self->{+PASS} = 1;
    }
    elsif(defined $self->{+PASS}) {
        $self->{+PASS} = 0;
    }

    my $name  = $self->{+NAME};
    my $dbg   = $self->{+DEBUG};
    my $pass  = $self->{+PASS};
    my $todo  = defined $dbg->todo;
    my $skip  = defined $dbg->skip;
    my $epass = $pass || $todo || $skip || 0;
    my $diag  = delete $self->{+DIAG};

    $self->{+EFFECTIVE_PASS} = $epass ? 1 : 0;

    unless ($pass || ($todo && $skip)) {
        my $msg = $todo ? "Failed (TODO)" : "Failed";
        my $prefix = $ENV{HARNESS_ACTIVE} ? "\n" : "";

        my $trace = $dbg->trace;

        if (defined $name) {
            $msg = qq[$prefix  $msg test '$name'\n  $trace.];
        }
        else {
            $msg = qq[$prefix  $msg test $trace.];
        }

        $self->add_diag($msg);
    }

    $self->add_diag(@$diag) if $diag && @$diag && !$pass;
}

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $name  = $self->{+NAME};
    my $debug = $self->{+DEBUG};
    my $skip  = $debug->skip;
    my $todo  = $debug->todo;

    my $out = "";
    $out .= "not " unless $self->{+PASS};
    $out .= "ok";
    $out .= " $num" if defined $num;

    if ($name) {
        $name =~ s|#|\\#|g; # '#' in a name can confuse Test::Harness.
        $out .= " - $name";
    }

    if (defined $skip && defined $todo) {
        $out .= " # TODO & SKIP";
        $out .= " $todo" if length $todo;
    }
    elsif (defined $todo) {
        $out .= " # TODO";
        $out .= " $todo" if length $todo;
    }
    elsif (defined $skip) {
        $out .= " # skip";
        $out .= " $skip" if length $skip;
    }

    $out =~ s/\n/\n# /g;

    return [OUT_STD, "$out\n"] unless $self->{+DIAG};

    return (
        [OUT_STD, "$out\n"],
        map {$_->to_tap($num)} @{$self->{+DIAG}},
    );
}

sub add_diag {
    my $self = shift;

    for my $item (@_) {
        next unless $item;

        if (ref $item) {
            confess("Only diag objects can be linked to events.")
                unless blessed($item) && $item->isa('Test::Stream::Event::Diag');

            $item->link($self);
        }
        else {
            $item = Test::Stream::Event::Diag->new(
                debug   => $self->{+DEBUG},
                nested  => $self->{+NESTED},
                message => $item,
                linked  => $self,
            );
        }

        push @{$self->{+DIAG}} => $item;
    }
}

sub update_state { $_[1]->bump($_[0]->effective_pass); undef }

sub subevents { @{$_[0]->{+DIAG} || []} }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Ok - Ok event type

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

Ok events are generated whenever you run a test that produces a result.
Examples are C<ok()>, and C<is()>.

=head1 SYNOPSIS

    use Test::Stream::Context qw/context/;
    use Test::Stream::Event::Ok;

    my $ctx = context();
    my $event = $ctx->ok($bool, $name, \@diag);

or:

    my $ctx   = debug();
    my $event = $ctx->send_event(
        'Ok',
        pass => $bool,
        name => $name,
        diag => \@diag
    );

=head1 ACCESSORS

=over 4

=item $rb = $e->pass

The original true/false value of whatever was passed into the event (but
reduced down to 1 or 0).

=item $name = $e->name

Name of the test.

=item $diag = $e->diag

An arrayref with all the L<Test::Stream::Event::Diag> events reduced down to
just the messages. Some coaxing has beeen done to combine all the messages into
a single string.

=item $b = $e->effective_pass

This is the true/false value of the test after TODO, SKIP, and similar
modifiers are taken into account.

=back

=head1 METHODS

=over 4

=item $e->add_diag($diag_event, "diag message" ...)

Add a diag to the event. The diag may be a diag event, or a simple string.

=item @sets = $e->to_tap()

=item @sets = $e->to_tap($num)

Generate the tap stream for this object. C<@sets> containes 1 or more arrayrefs
that identify the IO handle to use, and the string that should be sent to it.

IO Handle identifiers are set to the value of the L<Test::Stream::TAP> C<OUT_*>
constants.

Example:

    @sets = (
        [OUT_STD() => 'not ok 1 - foo'],
        [OUT_ERR() => '# Test 1 Failed ...' ],
        ...
    );

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
