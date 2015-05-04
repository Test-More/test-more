package Test::Stream::Event::Subtest;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Test::Stream::Carp qw/confess/;

use Test::Stream::Event(
    base       => 'Test::Stream::Event::Ok',
    accessors  => [qw/state events exception early_return buffer spec/],
);

sub init {
    my $self = shift;
    $self->{+EVENTS} ||= [];

    $self->{+PASS} = $self->{+STATE}->is_passing && $self->{+STATE}->count;

    if ($self->{+EXCEPTION}) {
        push @{$self->{+DIAG}} => "Exception in subtest '$self->{+NAME}': $self->{+EXCEPTION}";
        $self->{+STATE}->is_passing(0);
        $self->{+EFFECTIVE_PASS} = 0;
        $self->{+PASS} = 0;
    }

    if (my $le = $self->{+EARLY_RETURN}) {
        my $is_skip = $le->isa('Test::Stream::Event::Plan');
        $is_skip &&= $le->directive;
        $is_skip &&= $le->directive eq 'SKIP';

        if ($is_skip) {
            my $skip = $le->reason || "skip all";
            # Should be a snapshot now:
            $self->{+CONTEXT}->set_skip($skip);
            $self->{+PASS} = 1;
        }
        else { # BAILOUT
            $self->{+PASS} = 0;
        }
    }

    push @{$self->{+DIAG}} => "  No tests run for subtest."
        unless $self->{+EXCEPTION} || $self->{+EARLY_RETURN} || $self->{+STATE}->count;

    # Have the 'OK' init run
    $self->SUPER::init();
}

sub subevents {
    return (
        @{$_[0]->{+DIAG} || []},
        map { $_, $_->subevents } @{$_[0]->{+EVENTS} || []},
    );
}

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $buffer = $self->{+BUFFER};
    my $spec   = $self->{+SPEC};

    unless ($buffer) {
        return if $self->{+EXCEPTION}
               && $self->{+EXCEPTION}->isa('Test::Stream::Event::Bail');

        return $self->SUPER::to_tap($num);
    }

    # Subtest final result first
    my $is_block = $spec eq 'block';
    $self->{+NAME} =~ s/$/ {/mg if $is_block;
    my @out = (
        $self->SUPER::to_tap($num),
        $self->_render_events($num),
    );
    if ($is_block) {
        push @out => [OUT_STD, "}\n"];
        $self->{+NAME} =~ s/ \{$//mg;
    }
    else {
        push @out => [OUT_STD, "# End Subtest: $num - $self->{+NAME}\n"];
    }
    return @out;
}

sub _render_events {
    my $self = shift;
    my ($num) = @_;

    my $buffered = $self->{+BUFFER};

    my $idx = 0;
    my @out;
    for my $e (@{$self->events}) {
        next unless $e->can('to_tap');
        $idx++ if $e->isa('Test::Stream::Event::Ok');
        push @out => $e->to_tap($idx, $buffered);
    }

    for my $set (@out) {
        $set->[1] =~ s/^/    /mg;
    }

    return @out;
}

sub extra_details {
    my $self = shift;

    my @out = $self->SUPER::extra_details();
    my $plan = $self->{+STATE}->plan;
    my $exception = $self->exception;

    return (
        @out,

        events => $self->events || undef,

        exception => $exception || undef,
        plan      => $plan      || undef,

        passing => $self->{+STATE}->is_passing || 0,
        count   => $self->{+STATE}->count      || 0,
        failed  => $self->{+STATE}->failed     || 0,
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Event::Subtest - Subtest event

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

This event is used to encapsulate subtests.

=head1 SYNOPSIS

B<YOU PROBABLY DO NOT WANT TO DIRECTLY GENERATE A SUBTEST EVENT>. See the
C<subtest()> function from L<Test::More::Tools> instead.

=head1 INHERITENCE

the C<Test::Stream::Event::Subtest> class inherits from
L<Test::Stream::Event::Ok> and shares all of its methods and fields.

=head1 ACCESSORS

=over 4

=item my $se = $e->events

This returns an arrayref with all events generated during the subtest.

=item my $x = $e->exception

If the subtest was killed by a C<skip_all> or C<BAIL_OUT> the event will be
returned by this accessor.

=back

=head1 SUMMARY FIELDS

C<Test::Stream::Event::Subtest> inherits all of the summary fields from
L<Test::Stream::Event::Ok>.

=over 4

=item events => \@subevents

An arrayref containing all the events generated within the subtest, including
plans.

=item exception => \$plan_or_bail

If the subtest was aborted due to a bail-out or a skip_all, the event that
caused the abort will be here (in addition to the events arrayref.

=item plan => \$plan

The plan event for the subtest, this may be auto-generated.

=item passing => $bool

True if the subtest was passing, false otherwise. This should not be confused
with 'bool' inherited from L<Test::Stream::Event::Ok> which takes TODO into
account.

=item count => $num

Number of tests run inside the subtest.

=item failed => $num

Number of tests that failed inside the subtest.

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
