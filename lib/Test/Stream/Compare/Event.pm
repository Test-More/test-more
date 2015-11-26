package Test::Stream::Compare::Event;
use strict;
use warnings;

use Scalar::Util qw/blessed/;

use Test::Stream::Compare::EventMeta();

use base 'Test::Stream::Compare::Object';
use Test::Stream::HashBase accessors => [qw/etype/];

sub name {
    my $self = shift;
    my $etype = $self->etype;
    return "<EVENT: $etype>"
}

sub meta_class  { 'Test::Stream::Compare::EventMeta' }
sub object_base { 'Test::Stream::Event' }

sub got_lines {
    my $self = shift;
    my ($event) = @_;
    return unless $event;
    return unless blessed($event);
    return unless $event->isa('Test::Stream::Event');

    return ($event->debug->line);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Event - Event specific Object subclass.

=head1 DESCRIPTION

This module is used to represent an expected event in a deep comparison.

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
