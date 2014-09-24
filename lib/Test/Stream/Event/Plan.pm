package Test::Stream::Event::Plan;
use strict;
use warnings;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event(
    accessors => [qw/max directive reason/],
);

use Test::Stream::Carp qw/confess/;

my %ALLOWED = (
    'SKIP'    => 1,
    'NO PLAN' => 1,
);

sub init {
    if ($_[0]->[DIRECTIVE]) {
        $_[0]->[DIRECTIVE] = 'SKIP'    if $_[0]->[DIRECTIVE] eq 'skip_all';
        $_[0]->[DIRECTIVE] = 'NO PLAN' if $_[0]->[DIRECTIVE] eq 'no_plan';

        confess "'" . $_[0]->[DIRECTIVE] . "' is not a valid plan directive"
            unless $ALLOWED{$_[0]->[DIRECTIVE]};
    }
    else {
        $_[0]->[DIRECTIVE] = '';
        confess "Cannot have a reason without a directive!"
            if defined $_[0]->[REASON];

        confess "No number of tests specified"
            unless defined $_[0]->[MAX];


    }
}

sub to_tap {
    my $self = shift;

    my $max       = $self->[MAX];
    my $directive = $self->[DIRECTIVE];
    my $reason    = $self->[REASON];

    return if $directive && $directive eq 'NO PLAN';

    my $plan = "1..$max";
    if ($directive) {
        $plan .= " # $directive";
        $plan .= " $reason" if defined $reason;
    }

    return [OUT_STD, "$plan\n"];
}

1;

__END__

=head1 NAME

Test::Stream::Event::Plan - The event of a plan

=head1 DESCRIPTION

The plan event object.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

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
