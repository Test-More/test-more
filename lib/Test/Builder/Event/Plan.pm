package Test::Builder::Event::Plan;
use strict;
use warnings;

use base 'Test::Builder::Event';

use Carp qw/confess/;

sub max       { $_[0]->{max}       }
sub directive { $_[0]->{directive} }
sub reason    { $_[0]->{reason}    }

sub init {
    my ($self, $context, $max, $directive, $reason) = @_;

    confess "Cannot have a reason without a directive!"
        if defined $reason && !defined $directive;

    $self->{max}       = $max;
    $self->{directive} = $directive;
    $self->{reason}    = $reason;
}

sub to_tap {
    my $self = shift;

    my $max       = $self->{max};
    my $directive = $self->{directive};
    my $reason    = $self->{reason};

    return if $directive && $directive eq 'NO_PLAN';

    my $plan = "1..$max";
    if (defined $directive) {
        $plan .= " # $directive";
        $plan .= " $reason" if defined $reason;
    }

    return "$plan\n";
}

1;

__END__

=head1 NAME

Test::Builder::Event::Plan - The event of a plan

=head1 DESCRIPTION

The plan event object.

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
