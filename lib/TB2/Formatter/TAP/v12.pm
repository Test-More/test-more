package TB2::Formatter::TAP::v12;

use 5.008001;

use TB2::Mouse;
extends 'TB2::Formatter::TAP::Base';

our $VERSION = '1.005000_005';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::Formatter::TAP::v12 - TAP version 12 formatter

=head1 DESCRIPTION

Like L<TB2::Formatter::TAP::Base>, but it will not show a TAP version header.

=head1 SEE ALSO

L<TB2::Formatter::TAP>
L<TB2::Formatter::TAP::Base>
L<TB2::Formatter::TAP::v12>

=cut

has '+show_tap_version' =>
  default => 0;

1;
