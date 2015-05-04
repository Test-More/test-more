package Test::Stream::ExitMagic;
use strict;
use warnings;

use Test::Stream::ExitMagic::Context;

use Test::Stream::HashBase(
    accessors => [qw/pid done/],
);

sub init {
    $_[0]->{+PID}  = $$;
    $_[0]->{+DONE} = 0;
}

sub do_magic {
    my $self = shift;
    my ($hub, $context) = @_;
    return unless $hub;
    return if $hub->no_ending && !$context;

    # Don't bother with an ending if this is a forked copy.  Only the parent
    # should do the ending.
    return unless $self->{+PID} == $$;

    # Only run once
    return if $self->{+DONE}++;

    my $real_exit_code = $?;

    $context ||= Test::Stream::ExitMagic::Context->new(frame => [caller()], hub => $hub);

    if (!$hub->ended && $hub->follow_ups && @{$hub->follow_ups}) {
        $context->set;
        $_->($context) for @{$hub->follow_ups};
        $context->clear;
    }

    my $plan  = $hub->plan;
    my $total = $hub->count;
    my $fails = $hub->failed;

    $context->finish($total, $fails);

    # Ran tests but never declared a plan or hit done_testing
    return $self->no_plan_magic($hub, $context, $total, $fails, $real_exit_code)
        if $total && !$plan;

    # Exit if plan() was never called.  This is so "require Test::Simple"
    # doesn't puke.
    return unless $plan;

    # Don't do an ending if we bailed out.
    if( $hub->bailed_out ) {
        $hub->is_passing(0);
        return;
    }

    # Figure out if we passed or failed and print helpful messages.
    return $self->be_helpful_magic($hub, $context, $total, $fails, $plan, $real_exit_code)
        if $total && $plan;

    if ($plan->directive && $plan->directive eq 'SKIP') {
        $? = 0;
        return;
    }

    if($real_exit_code) {
        $context->diag("Looks like your test exited with $real_exit_code before it could output anything.\n");
        $hub->is_passing(0);
        $? = $real_exit_code;
        return;
    }

    unless ($total) {
        $context->diag("No tests run!\n");
        $hub->is_passing(0);
        $? = 255;
        return;
    }

    $hub->is_passing(0);
    $? = 255;
}

sub no_plan_magic {
    my $self = shift;
    my ($hub, $context, $total, $fails, $real_exit_code) = @_;

    $hub->is_passing(0);
    $context->diag("Tests were run but no plan was declared and done_testing() was not seen.");

    if($real_exit_code) {
        $context->diag("Looks like your test exited with $real_exit_code just after $total.\n");
        $? = $real_exit_code;
        return;
    }

    # But if the tests ran, handle exit code.
    if ($total && $fails) {
        my $exit_code = $fails <= 254 ? $fails : 254;
        $? = $exit_code;
        return;
    }

    $? = 254;
    return;
}

sub be_helpful_magic {
    my $self = shift;
    my ($hub, $context, $total, $fails, $plan, $real_exit_code) = @_;

    my $planned   = $plan->max;
    my $num_extra = $plan->directive && $plan->directive eq 'NO PLAN' ? 0 : $total - $planned;

    if ($num_extra != 0) {
        my $s = $planned == 1 ? '' : 's';
        $context->diag("Looks like you planned $planned test$s but ran $total.\n");
        $hub->is_passing(0);
    }

    if($fails) {
        my $s = $fails == 1 ? '' : 's';
        my $qualifier = $num_extra == 0 ? '' : ' run';
        $context->diag("Looks like you failed $fails test$s of ${total}${qualifier}.\n");
        $hub->is_passing(0);
    }

    if($real_exit_code) {
        $context->diag("Looks like your test exited with $real_exit_code just after $total.\n");
        $hub->is_passing(0);
        $? = $real_exit_code;
        return;
    }

    my $exit_code;
    if($fails) {
        $exit_code = $fails <= 254 ? $fails : 254;
    }
    elsif($num_extra != 0) {
        $exit_code = 255;
    }
    else {
        $exit_code = 0;
    }

    $? = $exit_code;
    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::ExitMagic - Encapsulate the magic exit logic

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

It's magic! well kinda..

=head1 SYNOPSIS

Don't use this yourself, let L<Test::Stream> handle it.

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
