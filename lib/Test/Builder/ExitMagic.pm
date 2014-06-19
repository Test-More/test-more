package Test::Builder::ExitMagic;
use strict;
use warnings;

my $global = __PACKAGE__->new;
END { $global->do_magic() if $global }

sub new {
    my $class = shift;
    my $params = {@_};
    return bless $params, $class;
}

sub stream {
    my $self = shift;
    ($self->{stream}) = @_ if @_;
    return $self->{stream};
}

sub tb {
    my $self = shift;
    ($self->{tb}) = @_ if @_;
    return $self->{tb};
}

sub ended {
    my $self = shift;
    ($self->{ended}) = @_ if @_;
    return $self->{ended};
}


sub do_magic {
    my $self = shift;

    local $@;

    require Test::Builder::Stream;
    require Test::Builder;

    my $stream = $self->stream || (Test::Builder::Stream->root ? Test::Builder::Stream->shared : undef);
    return unless $stream; # No stream? no point!
    my $tb = $self->tb || Test::Builder->new;

    return if $stream->no_ending;
    return if $self->ended; $self->ended(1);

    my $real_exit_code = $?;

    # Don't bother with an ending if this is a forked copy.  Only the parent
    # should do the ending.
    return unless $stream->pid == $$;

    my $plan  = $stream->plan;
    my $total = $stream->tests_run;
    my $fails = $stream->tests_failed;

    require Test::Builder::Result::Finish;
    $stream->send(
        Test::Builder::Result::Finish->new(
            tests_run    => $total,
            tests_failed => $fails,
            depth        => $tb->depth,

            context => {
                caller => [__PACKAGE__, __FILE__, __LINE__],
                pid    => $$,
            },
        )
    );

    # Ran tests but never declared a plan or hit done_testing
    return $self->no_plan_magic($stream, $tb, $total, $fails, $real_exit_code)
        if $total && !$plan;

    # Exit if plan() was never called.  This is so "require Test::Simple"
    # doesn't puke.
    return unless $plan;

    # Don't do an ending if we bailed out.
    if( $tb->{Bailed_Out} ) {
        $tb->is_passing(0);
        return;
    }

    # Figure out if we passed or failed and print helpful messages.
    return $self->be_helpful_magic($stream, $tb, $total, $fails, $plan, $real_exit_code)
        if $total && $plan;

    if ($plan->directive && $plan->directive eq 'SKIP') {
        $? = 0;
        return;
    }

    if($real_exit_code) {
        $tb->diag(<<"FAIL");
Looks like your test exited with $real_exit_code before it could output anything.
FAIL
        $stream->is_passing(0);
        $? = $real_exit_code;
        return;
    }

    unless ($total) {
        $tb->diag("No tests run!\n");
        $tb->is_passing(0);
        $? = 255;
        return;
    }

    $tb->is_passing(0);
    $tb->_whoa( 1, "We fell off the end of _ending()" );

    1;
}

sub no_plan_magic {
    my $self = shift;
    my ($stream, $tb, $total, $fails, $real_exit_code) = @_;

    $stream->is_passing(0);
    $tb->diag("Tests were run but no plan was declared and done_testing() was not seen.");
    
    if($real_exit_code) {
        $tb->diag("Looks like your test exited with $real_exit_code just after $total.\n");
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
    my ($stream, $tb, $total, $fails, $plan, $real_exit_code) = @_;

    my $planned   = $plan->max;
    my $num_extra = $plan->directive && $plan->directive eq 'NO_PLAN' ? 0 : $total - $planned;

    if ($num_extra != 0) {
        my $s = $planned == 1 ? '' : 's';
        $tb->diag("Looks like you planned $planned test$s but ran $total.\n");
        $tb->is_passing(0);
    }

    if($fails) {
        my $s = $fails == 1 ? '' : 's';
        my $qualifier = $num_extra == 0 ? '' : ' run';
        $tb->diag("Looks like you failed $fails test$s of ${total}${qualifier}.\n");
        $tb->is_passing(0);
    }

    if($real_exit_code) {
        $tb->diag("Looks like your test exited with $real_exit_code just after $total.\n");
        $tb->is_passing(0);
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
