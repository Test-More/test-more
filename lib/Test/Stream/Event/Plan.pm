package Test::Stream::Event::Plan;
use strict;
use warnings;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event;
BEGIN {
    accessors qw/max directive reason/;
    Test::Stream::Event->cleanup;
};

use Carp qw/confess/;

sub init {
    confess "Cannot have a reason without a directive!"
        if defined $_[0]->[REASON] && !defined $_[0]->[DIRECTIVE];
}

sub to_tap {
    my $self = shift;

    my $max       = $self->[MAX];
    my $directive = $self->[DIRECTIVE];
    my $reason    = $self->[REASON];

    return if $directive && $directive eq 'NO_PLAN';

    my $plan = "1..$max";
    if (defined $directive) {
        $plan .= " # $directive";
        $plan .= " $reason" if defined $reason;
    }

    return (OUT_STD, "$plan\n");
}

1;

__END__

=head1 NAME

Test::Stream::Event::Plan - The event of a plan

=head1 DESCRIPTION

The plan event object.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

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
