package Test::Builder::Event;
use strict;
use warnings;

use Carp qw/confess croak/;
use Scalar::Util qw/blessed/;

use Test::Builder::Util qw/accessors/;

my @ACCESSORS = qw/created context/;

sub init {};

sub new {
    my ($class, $context, $created, @more) = @_;

    croak "No context provided!" unless $context;

    unless($created) {
        my ($p, $f, $l, $s) = caller;
        $created = [$p, $f, $l, $s];
    }

    my $self = bless {
        context => $context,
        created => $created,
    }, $class;

    $self->init($context, @more) if @more;

    return $self;
}

for my $name (@ACCESSORS) {
    no strict 'refs';
    *$name = sub { $_[0]->{$name} };
}

sub indent {
    my $self = shift;
    my $depth = $self->{context}->depth || return;
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
