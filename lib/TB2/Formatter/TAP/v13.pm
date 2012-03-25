package TB2::Formatter::TAP::v13;

use 5.008001;

use TB2::Mouse;
extends 'TB2::Formatter::TAP::Base';

our $VERSION = '1.005000_004';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Formatter::TAP::v13 - TAP version 13 formatter

=head1 DESCRIPTION

Like L<TB2::Formatter::TAP::Base>, but it will show the TAP version header.

This is the default formatter provided by L<TB2::Formatter::TAP>.

=head1 SEE ALSO

L<TB2::Formatter::TAP>
L<TB2::Formatter::TAP::Base>

=cut

has '+show_tap_version' =>
  default => 1;

1;
