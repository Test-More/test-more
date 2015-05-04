package Test::Stream::Tester::Grab;
use strict;
use warnings;

sub new {
    my $class = shift;

    my $self = bless {
        events  => [],
        hubs => [ Test::Stream->intercept_start ],
    }, $class;

    $self->{hubs}->[0]->listen(
        sub {
            shift;    # Stream
            push @{$self->{events}} => @_;
        }
    );

    return $self;
}

sub flush {
    my $self = shift;
    my $out = delete $self->{events};
    $self->{events} = [];
    return $out;
}

sub events {
    my $self = shift;
    # Copy
    return [@{$self->{events}}];
}

sub finish {
    my ($self) = @_; # Do not shift;
    $_[0] = undef;

    $self->{finished} = 1;
    my ($remove) = $self->{hubs}->[0];
    Test::Stream->intercept_stop($remove);

    return $self->flush;
}

sub DESTROY {
    my $self = shift;
    return if $self->{finished};
    my ($remove) = $self->{hubs}->[0];
    Test::Stream->intercept_stop($remove);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Tester::Grab - Object used to temporarily steal all events.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head2 BACKWARDS COMPATABILITY SHIM

By default, loading Test-Stream will block Test::Builder and related namespaces
from loading at all. You can work around this by loading the compatability shim
which will populate the Test::Builder and related namespaces with a
compatability implementation on demand.

    use Test::Stream::Shim;
    use Test::Builder;
    use Test::More;

B<Note:> Modules that are experimenting with Test::Stream should NOT load the
shim in their module files. The shim should only ever be loaded in a test file.


=head1 DESCRIPTION

Once created this object will intercept and stash all events sent to the shared
L<Test::Stream::Hub> object. Once the object is destroyed events will once
again be sent to the shared hub.

=head1 SYNOPSIS

    use Test::More;
    use Test::Stream::Tester::Grab;

    my $grab = Test::Stream::Tester::Grab->new();

    # Generate some events, they are intercepted.
    ok(1, "pass");
    ok(0, "fail");

    my $events_a = $grab->flush;

    # Generate some more events, they are intercepted.
    ok(1, "pass");
    ok(0, "fail");

    # Same as flush, except it destroys the grab object.
    my $events_b = $grab->finish;

After calling C<finish()> the grab object is destroyed and C<$grab> is set to
undef. C<$events_a> is an arrayref with the first 2 events. C<$events_b> is an
arrayref with the second 2 events.

=head1 METHODS

=over 4

=item $grab = $class->new()

Create a new grab object, immediately starts intercepting events.

=item $ar = $grab->flush()

Get an arrayref of all the events so far, clearing the grab objects internal
list.

=item $ar = $grab->events()

Get an arrayref of all events so far, does not clear the internal list.

=item $ar = $grab->finish()

Get an arrayref of all the events, then destroy the grab object.

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
