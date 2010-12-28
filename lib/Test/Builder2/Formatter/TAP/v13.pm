package Test::Builder2::Formatter::TAP::v13;

use 5.008001;

use Test::Builder2::Mouse;
use Carp;
use Test::Builder2::Types;

use Test::Builder2::threads::shared;

extends 'Test::Builder2::Formatter';

has indent_nesting_with =>
  is            => 'rw',
  isa           => 'Str',
  default       => "    "
;

sub default_streamer_class { 'Test::Builder2::Streamer::TAP' }


sub make_singleton {
    my $class = shift;

    require Test::Builder2::Counter;
    $class->create(
        counter => shared_clone( Test::Builder2::Counter->create )
    );
}


=head1 NAME

Test::Builder2::Formatter::TAP::v13 - Formatter as TAP version 13

=head1 SYNOPSIS

  use Test::Builder2::Formatter::TAP::v13;

  my $formatter = Test:::Builder2::Formatter::TAP::v13->new;
  $formatter->accept_event($event);
  $formatter->accept_result($result);


=head1 DESCRIPTION

Formatter Test::Builder2::Result's as TAP version 13.

=head1 METHODS

As Test::Builder2::Object with the following changes and additions.

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

sub _add_indentation {
    my $self = shift;
    my $output = shift;

    my $level = $self->stream_depth - 1;
    return unless $level;

    my $indent = $self->indent_nesting_with x $level;
    for my $idx (0..$#{$output}) {
        $output->[$idx] = $self->_prepend($output->[$idx], $indent);
    }

    return;
}

sub out {
    my $self = shift;
    $self->_add_indentation(\@_);
    $self->write(out => @_);
}

sub err {
    my $self = shift;
    $self->_add_indentation(\@_);
    $self->write(err => @_);
}


=head3 counter

    my $counter = $formatter->counter;
    $formatter->counter($counter);

Gets/sets the Test::Builder2::Counter for this formatter keeping track of
the test number.

=cut

has counter => 
   is => 'rw',
   isa => 'Test::Builder2::Counter',
   default => sub {
      require Test::Builder2::Counter;
      return Test::Builder2::Counter->create;
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

my %event_dispatch = (
    "stream start"      => "accept_stream_start",
    "stream end"        => "accept_stream_end",
    "set plan"          => "accept_set_plan",
);

sub INNER_accept_event {
    my $self  = shift;
    my $event = shift;

    my $type = $event->event_type;
    my $method = $event_dispatch{$type};
    return unless $method;

    $self->$method($event);

    return;
}


has show_tap_version =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 1
;

sub accept_stream_start {
    my $self = shift;

    # Only output the TAP header once
    $self->out("TAP version 13\n") if $self->stream_depth == 1 and $self->show_tap_version;

    return;
}


sub accept_stream_end {
    my $self = shift;

    $self->output_plan unless $self->did_output_plan;
#    $self->do_ending if $self->stream_depth == 0;

    # New counter
    $self->counter( Test::Builder2::Counter->create );

    return;
}


has plan =>
  is            => 'rw',
  isa           => 'Object'
;

sub accept_set_plan {
    my $self  = shift;
    my $event = shift;

    croak "'set plan' event outside of a stream" if !$self->stream_depth;

    $self->plan( $event );

    # TAP only allows a plan at the very start or the very end.
    # If we've already seen some results, save it for the end.
    $self->output_plan unless $self->seen_results or $event->no_plan;

    return;
}


has did_output_plan =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

sub output_plan {
    my $self  = shift;
    my $plan = $self->plan;

    croak "No plan was seen" if !$plan;

    if( $plan->skip ) {
        my $reason = $plan->skip_reason;
        $self->out("1..0 # skip $reason");
    }
    elsif( $plan->no_plan ) {
        my $seen = $self->counter->get;
        $self->out("1..$seen\n");
    }
    elsif( my $expected = $plan->asserts_expected ) {
        $self->out("1..$expected\n");
    }

    $self->did_output_plan(1);

    return;
}


=head3 INNER_accept_result

Takes a C<Test::Builder2::Result> as an argument and displays the
result details.

=cut

has seen_results =>
  is            => 'rw',
  isa           => 'Bool',
  default       => 0
;

sub INNER_accept_result {
    my $self  = shift;
    my $result = shift;

    # FIXME: there is a lot more detail in the 
    # result object that I ought to do deal with.

    my $out = "";
    $out .= "not " if !$result->literal_pass;
    $out .= "ok";

    my $num = $result->test_number || $self->counter->increment;
    $out .= " ".$num if $self->use_numbers;

    my $name = $result->description;
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

    $$string =~ s{\n}{\\n}g;

    return;
}


1;
