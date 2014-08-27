package Test::Builder::Event::Finish;
use strict;
use warnings;

use base 'Test::Builder::Event';

sub tests_run    { $_[0]->{tests_run}    }
sub tests_failed { $_[0]->{tests_failed} }

sub init {
    my ($self, $context, $run, $failed) = @_;

    $self->{tests_run}    = $run;
    $self->{tests_failed} = $failed;
}

1;

__END__

=head1 NAME

Test::Builder::Event::Finish - The finish event type

=head1 DESCRIPTION

Sent after testing is finished.

=head1 METHODS

See L<Test::Builder::Event> which is the base class for this module.

=head2 CONSTRUCTORS

=over 4

=item $r = $class->new(...)

Create a new instance

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
