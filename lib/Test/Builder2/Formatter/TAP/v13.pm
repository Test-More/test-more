package Test::Builder2::Formatter::TAP::v13;

use 5.008001;

use Test::Builder2::Mouse;
use Carp;
use Test::Builder2::Types;

extends 'Test::Builder2::Formatter';

has nesting_level =>
  is            => 'rw',
  isa           => 'Test::Builder2::Positive_Int',
  default       => 0
;

has indent_nesting_with =>
  is            => 'rw',
  isa           => 'Str',
  default       => "    "
;

sub default_streamer_class { 'Test::Builder2::Streamer::TAP' }

=head1 NAME

Test::Builder2::Formatter::TAP::v13 - Formatter as TAP version 13

=head1 SYNOPSIS

  use Test::Builder2::Formatter::TAP::v13;

  my $formatter = Test:::Builder2::Formatter::TAP::v13->new;
  $formatter->begin();
  $formatter->result($result);
  $formatter->end($plan);


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

sub _add_indentation {
    my $self = shift;
    my $output = shift;

    my $level = $self->nesting_level;
    return unless $level;

    unshift @$output, $self->indent_nesting_with x $level;

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

=head3 begin

The %plan can be one and only one of...

  tests => $number_of_tests

  no_plan => 1

  skip_all => $reason

=cut

sub INNER_begin {
    my $self = shift;
    my %args = @_;

    croak "begin() takes only one pair of arguments" if keys %args > 1;

    $self->out("TAP version 13\n");

    if( exists $args{tests} ) {
        $self->out("1..$args{tests}\n");
    }
    elsif( exists $args{skip_all} ) {
        $self->out("1..0 # skip $args{skip_all}");
    }
    elsif( exists $args{no_plan} ) {
        # ...do nothing...
    }
    elsif( keys %args == 1 ) {
        croak "Unknown argument @{[ keys %args ]} to begin()";
    }
    else {
        # ...do nothing...
    }

    return;
}

=head3 result

Takes a C<Test::Builder2::Result> as an argument and displays the
result details.

=cut

sub INNER_result {
    my $self = shift;
    my $result = shift;

    # FIXME: there is a lot more detail in the 
    # result object that I ought to do deal with.

    my $out = "";
    $out .= "not " if !$result->literal_pass;
    $out .= "ok";

    $out .= " ".$result->test_number   if defined $result->test_number;

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

    return;
}


sub _escape {
    my $self = shift;
    my $string = shift;

    return if !defined $$string;

    $$string =~ s{\n}{\\n}g;

    return;
}

=head3 end

Similar to C<begin()>, it takes either no or one and only one pair of arguments.

  tests => $number_of_tests

=cut

sub INNER_end {
    my $self = shift;

    my %args = @_;

    croak "end() takes only one pair of arguments" if keys %args > 1;

    if( exists $args{tests} ) {
        $self->out("1..$args{tests}\n");
    }
    elsif( keys %args == 1 ) {
        croak "Unknown argument @{[ keys %args ]} to end()";
    }
    else {
        # ...do nothing...
    }

    return;    
}

1;
