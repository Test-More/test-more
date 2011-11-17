package TB2::Formatter::TAP::v13;

use 5.008001;

use TB2::Mouse;
use TB2::Types;
extends 'TB2::Formatter';
with 'TB2::CanLoad';

our $VERSION = '1.005000_001';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use Carp;
use TB2::threads::shared;

sub default_streamer_class { 'TB2::Streamer::TAP' }


=head1 NAME

TB2::Formatter::TAP::v13 - Formatter as TAP version 13

=head1 SYNOPSIS

  use TB2::Formatter::TAP::v13;

  my $formatter = Test:::Builder2::Formatter::TAP::v13->new;
  my $ec = TB2::EventCoordinator->create(
      formatters => [$formatter]
  );
  $ec->post_event($event);
  $ec->post_event($result);


=head1 DESCRIPTION

Formatter TB2::Result's as TAP version 13.

=head1 METHODS

As L<TB2::Formatter> with the following changes and additions.

=head3 out

=head3 err

These methods are just shorthand for:

  $output->write(out => @args);
  $output->write(err => @args);

=cut


sub _prepend {
    my($self, $msg, $prefix) = @_;

    # Put '# ' at the beginning of each line
    $msg =~ s{^}{$prefix};
    $msg =~ s{\n(?!\z)}{\n$prefix}g;

    return $msg;
}


sub _indent {
    my $self = shift;

    my $indent = $self->indent;
    my $msg = join "", @_;
    return $msg unless $indent;

    # Put an indent after each newline
    $msg =~ s{\n(?!\z)}{\n$indent}sg;

    return $indent . $msg;
}

sub out {
    my $self = shift;
    $self->write(out => $self->_indent(@_));
}

sub err {
    my $self = shift;
    $self->write(err => $self->_indent(@_));
}

sub diag {
    my $self = shift;
    $self->err($self->comment( @_ ));
}

sub note {
    my $self = shift;
    $self->out($self->comment( @_));
}


=head3 counter

    my $counter = $formatter->counter;
    $formatter->counter($counter);

Gets/sets the TB2::Counter for this formatter keeping track of
the test number.

=cut

has counter => 
   is => 'rw',
   isa => 'TB2::Counter',
   default => sub {
      $_[0]->load('TB2::Counter');
      return TB2::Counter->new;
   },
;

=head3 use_numbers

    my $use_numbers = $formatter->use_numbers;
    $formatter->use_numbers($use_numbers);

Get/sets if the TAP output should include the test number. Defaults to true.
NOTE: the counter will still incrememnt this only toggles if the number should
be used in the display.

=cut

has use_numbers => 
   is => 'rw',
   isa => 'Bool',
   default => 1,
;

has show_header =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

has show_footer =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

has show_tap_version =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

has show_plan =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

has show_ending_commentary =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

has show_logs =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

has indent =>
  is            => 'rw',
  isa           => 'Str',
  default       => ''
;


sub handle_test_start {
    my $self = shift;
    my($event, $ec) = @_;

    # Only output the TAP version if we're showing the version
    # and if we're showing header information
    $self->out("TAP version 13\n") if
      $self->show_tap_version  and
      $self->show_header;

    return;
}


sub handle_test_end {
    my $self  = shift;
    my $event = shift;
    my $ec    = shift;

    $self->output_plan if $self->show_footer;

    $self->output_ending_commentary($ec);

    return;
}


has plan =>
  is            => 'rw',
  isa           => 'Object'
;

sub handle_set_plan {
    my $self  = shift;
    my($event, $ec) = @_;

    croak "A plan was set but we're not testing" if !$ec->history->in_test;

    $self->plan( $event );

    # TAP only allows a plan at the very start or the very end.
    # If we've already seen some results, or it's "no_plan", save it for the end.
    $self->output_plan if !$self->seen_results and $self->show_header and !$event->no_plan;

    return;
}


has did_output_plan =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

sub output_plan {
    my $self = shift;

    return unless $self->show_plan;
    return if $self->did_output_plan;

    return if !$self->plan;

    $self->_output_plan;

    $self->did_output_plan(1);

    return 1;
}

sub _output_plan {
    my $self  = shift;
    my $plan = $self->plan;

    if( $plan->skip ) {
        my $reason = $plan->skip_reason;
        my $out = "1..0 # SKIP";
        $out .= " $reason" if length $reason;
        $out .= "\n";
        $self->out($out);
    }
    elsif( $plan->no_plan ) {
        my $seen = $self->counter->get;
        $self->out("1..$seen\n");
    }
    elsif( my $expected = $plan->asserts_expected ) {
        $self->out("1..$expected\n");
    }

    return;
}


my %inflections = (
    test        => "tests",
    was         => "were"
);
sub _inflect {
    my($word, $num) = @_;

    return $word if $num == 1;

    my $plural = $inflections{$word};
    return $plural ? $plural : $word;
}

sub output_ending_commentary {
    my $self = shift;
    my $ec   = shift;

    return unless $self->show_ending_commentary;

    my $plan = $self->plan;

    my $tests_run = $self->counter->get;
    my $w_test    = _inflect("test", $tests_run);

    my $tests_failed   = $ec->history->fail_count;
    my $tests_planned  = !$plan                         ? 0
                       : $plan->no_plan                 ? $tests_run
                       :                                  $plan->asserts_expected
                       ;
    my $tests_extra    = $tests_planned - $tests_run;


    # No plan was seen
    if( !$plan ) {
        # Ran tests but never declared a plan
        if( $tests_run ) {
            $self->diag("$tests_run $w_test ran, but no plan was declared.");
        }
        # No plan is ok if nothing happened
        else {
            return;
        }
    }


    # Skip
    if( $plan && $plan->skip ) {
        # It was supposed to be a skip, but tests were run
        if( $tests_run ) {
            $self->diag("The test was skipped, but $tests_run $w_test ran.");
        }
        # A proper skip
        else {
            return;
        }
    }

    # Saw a plan, but no tests.
    if( !$tests_run ) {
        $self->diag("No tests run!");
        return;
    }


    # Saw a plan, and tests, but not the right amount.
    if( $plan && $tests_planned && $tests_extra ) {
        my $w_tests_p = _inflect("test", $tests_planned);
        $self->diag("$tests_planned $w_tests_p planned, but $tests_run ran.");
    }


    # Right amount, but some failed.
    if( $tests_failed ) {
        my $w_tests_f = _inflect("test", $tests_failed);
        $self->diag("$tests_failed $w_tests_f of $tests_run failed.");
    }

    return;
}


=head3 handle_result

Takes a C<TB2::Result> as an argument and displays the
result details.

=cut

has seen_results =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

sub handle_result {
    my $self  = shift;
    my $result = shift;

    # FIXME: there is a lot more detail in the 
    # result object that I ought to do deal with.

    my $out = "";
    $out .= "not " if !$result->literal_pass;
    $out .= "ok";

    my $num = $result->test_number || $self->counter->increment;
    $out .= " ".$num if $self->use_numbers;

    my $name = $result->name;
    $self->_escape(\$name);
    $out .= " - $name" if defined $name and length $name;

    my $reason = $result->reason;
    $self->_escape(\$reason);

    my @directives;
    push @directives, "TODO" if $result->is_todo;
    push @directives, "SKIP" if $result->is_skip;

    $out .= " # @{[ join ' ', @directives ]} $reason" if @directives;
    $out .= "\n";

    $self->out($out);

    if(!$result->literal_pass and !$result->is_skip) {
        # XXX This should also emit structured diagnostics
        $self->_comment_diagnostics($result);
    }

    $self->seen_results(1);

    return;
}


# Emit old style comment failure diagnostics
sub _comment_diagnostics {
    my($self, $result) = @_;

    my $msg = '  ';

    $msg .= $result->is_todo ? "Failed (TODO) test" : "Failed test";

    # Failing TODO tests are not displayed to the user.
    my $out_method = $result->is_todo ? "out" : "err";

    my($file, $line, $name) = map { $result->$_ } qw(file line name);

    if( defined $name ) {
        $msg .= " '$name'\n ";
    }
    if( defined $file ) {
        $msg .= " at $file";
    }
    if( defined $line ) {
        $msg .= " line $line";
    }

    # Start on a new line if we're being output by Test::Harness.
    # Makes it easier to read
    $self->$out_method("\n") if $ENV{HARNESS_ACTIVE};
    $self->$out_method($self->comment("$msg.\n"));

    return;
}


=head3 comment

  my $comment = $self->comment(@message);

Will turn the given @message into a TAP comment.

    # returns "# Basset houndsgot long ears"
    $self->comment("Basset hounds", "got long ears");

=cut

sub comment {
    my $self = shift;

    return unless @_;

    # Smash args together like print does.
    # Convert undef to 'undef' so its readable.
    my $msg = join '', map { defined($_) ? $_ : 'undef' } @_;

    $msg = $self->_prepend($msg, "# ");

    # Stick a newline on the end if it needs it.
    $msg .= "\n" unless $msg =~ /\n\z/;

    return $msg;
}


sub _escape {
    my $self = shift;
    my $string = shift;

    return if !defined $$string;

    $$string =~ s{#}{\\#}g;
    $$string =~ s{\n}{\\n}g;

    return;
}


sub handle_log {
    my $self = shift;
    my($log, $ec) = @_;

    return if !$self->show_logs;

    if( $log->between_levels( "warning", "highest" ) ) {
        $self->diag( $log->message );
    }
    else {
        $self->note( $log->message );
    }

    return;
}


sub subtest_handler {
    my $self  = shift;
    my $event = shift;

    my $subformatter = $self->SUPER::subtest_handler($event);

    $subformatter->show_tap_version( $self->show_tap_version );
    $subformatter->indent('    '.$self->indent);

    return $subformatter;
}


sub handle_subtest_end {
    my $self = shift;
    my($event, $ec) = @_;

    my $subtest_start = $ec->history->subtest_start;

    my %result_args;

    # Did the subtest pass?
    $result_args{pass} = $event->history->test_was_successful;

    # Inherit the name from the subtest.
    $result_args{name} = $subtest_start->name;

    # If the subtest was started in a todo context, the subtest result
    # will be todo.
    $result_args{directives} = $subtest_start->directives;
    $result_args{reason}     = $subtest_start->reason;

    # Inherit the context.
    for my $key (qw(file line)) {
        my $val = $event->$key();
        $result_args{$key} = $val if defined $val;
    }

    # What was the result of the subtest?
    if( my $abort = $event->history->abort ) {
        # Subtest aborted, end the abort up to the top level
        $ec->post_event($abort);
    }
    else {
        my $subtest_plan = $event->history->plan;
        if( $subtest_plan && $subtest_plan->skip ) {
            # If the subtest was a skip_all, make our result a skip.
            $result_args{skip} = 1;
            $result_args{reason} = $subtest_plan->skip_reason;
        }
        elsif( $event->history->test_count == 0 ) {
            # The subtest didn't run any tests
            my $name = $result_args{name};
            $result_args{name} = "No tests run in subtest";
            $result_args{name}.= qq[ "$name"] if defined $name;
        }

        my $result = TB2::Result->new_result( %result_args );
        $ec->post_event($result);
    }

    return;
}


sub handle_abort {
    my $self = shift;
    my($event, $ec) = @_;

    # Only the top level will report the bailout.
    return if $ec->history->is_subtest;

    my $reason = $self->_escape_reason($event->reason);

    my $msg = "Bail out!";
    $msg   .= "  $reason" if length $reason;
    $self->out( "$msg\n" );

    return;
}


# TAP has no way to issue a multi-line bail out reason, so escape the newlines.
sub _escape_reason {
    my $self = shift;
    my $reason = shift;
    
    $reason =~ s{\n}{\\n}g;

    return $reason;
}

1;
