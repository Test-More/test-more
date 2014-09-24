package Test::Stream::ExitMagic;
use strict;
use warnings;

require Test::Stream::ExitMagic::Context;

use Test::Stream::ArrayBase(
    accessors => [qw/pid done/],
);

sub init {
    $_[0]->[PID]  = $$;
    $_[0]->[DONE] = 0;
}

sub do_magic {
    my $self = shift;
    my ($stream, $context) = @_;
    return unless $stream;
    return if $stream->no_ending && !$context;

    # Don't bother with an ending if this is a forked copy.  Only the parent
    # should do the ending.
    return unless $self->[PID] == $$;

    # Only run once
    return if $self->[DONE]++;

    my $real_exit_code = $?;

    my $plan  = $stream->plan;
    my $total = $stream->count;
    my $fails = $stream->failed;

    $context ||= Test::Stream::ExitMagic::Context->new([caller()], $stream);
    $context->finish($total, $fails);

    # Ran tests but never declared a plan or hit done_testing
    return $self->no_plan_magic($stream, $context, $total, $fails, $real_exit_code)
        if $total && !$plan;

    # Exit if plan() was never called.  This is so "require Test::Simple"
    # doesn't puke.
    return unless $plan;

    # Don't do an ending if we bailed out.
    if( $stream->bailed_out ) {
        $stream->is_passing(0);
        return;
    }

    # Figure out if we passed or failed and print helpful messages.
    return $self->be_helpful_magic($stream, $context, $total, $fails, $plan, $real_exit_code)
        if $total && $plan;

    if ($plan->directive && $plan->directive eq 'SKIP') {
        $? = 0;
        return;
    }

    if($real_exit_code) {
        $context->diag("Looks like your test exited with $real_exit_code before it could output anything.\n");
        $stream->is_passing(0);
        $? = $real_exit_code;
        return;
    }

    unless ($total) {
        $context->diag("No tests run!\n");
        $stream->is_passing(0);
        $? = 255;
        return;
    }

    $stream->is_passing(0);
    $? = 255;
}

sub no_plan_magic {
    my $self = shift;
    my ($stream, $context, $total, $fails, $real_exit_code) = @_;

    $stream->is_passing(0);
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
    my ($stream, $context, $total, $fails, $plan, $real_exit_code) = @_;

    my $planned   = $plan->max;
    my $num_extra = $plan->directive && $plan->directive eq 'NO PLAN' ? 0 : $total - $planned;

    if ($num_extra != 0) {
        my $s = $planned == 1 ? '' : 's';
        $context->diag("Looks like you planned $planned test$s but ran $total.\n");
        $stream->is_passing(0);
    }

    if($fails) {
        my $s = $fails == 1 ? '' : 's';
        my $qualifier = $num_extra == 0 ? '' : ' run';
        $context->diag("Looks like you failed $fails test$s of ${total}${qualifier}.\n");
        $stream->is_passing(0);
    }

    if($real_exit_code) {
        $context->diag("Looks like your test exited with $real_exit_code just after $total.\n");
        $stream->is_passing(0);
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

=head1 NAME

Test::Stream::ExitMagic - Encapsulate the magic exit logic

=head1 DESCRIPTION

It's magic! well kinda..

=head1 SYNOPSYS

Don't use this yourself, let L<Test::Stream> handle it.

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

Most of this code was pulled out ot L<Test::Builder>, written by Schwern and
others.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
