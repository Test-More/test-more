package Test::Builder::Event;
use strict;
use warnings;

use Carp qw/confess croak/;

use Test::Builder::ArrayBase;
BEGIN {
    accessors qw/context created/;
    Test::Builder::ArrayBase->cleanup;
};

sub init {
    confess "No context provided!" unless $_[0]->[CONTEXT];
}

sub indent {
    my $self = shift;
    my $depth = $self->[CONTEXT]->depth || return;
    return '    ' x $depth;
}

1;

__END__

=head1 NAME

Test::Builder::Event - Base class for events

=head1 DESCRIPTION

Base class for all event objects that get passed through
L<Test::Builder::Stream>.

=head1 METHODS

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
