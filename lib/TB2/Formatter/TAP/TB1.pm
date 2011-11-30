package TB2::Formatter::TAP::TB1;

use TB2::Mouse;
extends 'TB2::Formatter::TAP::v12';

=head1 NAME

TB2::Formatter::TAP::TB1 - TAP formatter for compatibily with 0.98

=head1 DESCRIPTION

This is a TAP formatter specifically designed to emulate the quirks of
Test::Builder 0.98, the last stable release of Test::Builder before
the TB2 architecture.  This is intended to provide Test module authors
with a smooth transition between 0.98 and 1.5.

=cut

# It was "# skip" but "# TODO"
has '+directive_display' =>
  default       => sub {
      return {
          skip  => 'skip',
          todo  => 'TODO'
      }
  };


# ok( 1, "" ) comes out as "ok 1 - "
has "+show_empty_result_names" =>
  default       => 1;


# Messages output as part of the ending commentary
has '+diag_tests_but_no_plan' =>
  default       => "Tests were run but no plan was declared and done_testing() was not seen.";

has '+diag_wrong_number_of_tests' =>
  default       => "Looks like you planned %d %s but ran %d.";

has '+diag_tests_failed' =>
  default       => "Looks like you failed %d %s of %d run.";

has '+diag_no_tests' =>
  default       => "No tests run!";

1;
