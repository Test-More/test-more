package Test2::AsyncSubtest::Hub;
use strict;
use warnings;

our $VERSION = '0.000092';

use base 'Test2::Hub::Subtest';
use Test2::Util::HashBase qw/ast_ids/;

sub init {
    my $self = shift;

    $self->SUPER::init();

    if (my $format = $self->format) {
        my $hide = $format->can('hide_buffered') ? $format->hide_buffered : 1;

        if ($hide) {
            $self->format(undef);
        }
        else {
            require Test2::AsyncSubtest::Formatter;
            $self->format(Test2::AsyncSubtest::Formatter->new(wrap => $format));
        }
    }
}

sub inherit {
    my $self = shift;
    my ($from, %params) = @_;

    if (my $ls = $from->{+_LISTENERS}) {
        push @{$self->{+_LISTENERS}} => grep { $_->{inherit} } @$ls;
    }

    if (my $pfs = $from->{+_PRE_FILTERS}) {
        push @{$self->{+_PRE_FILTERS}} => grep { $_->{inherit} } @$pfs;
    }

    if (my $fs = $from->{+_FILTERS}) {
        push @{$self->{+_FILTERS}} => grep { $_->{inherit} } @$fs;
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::AsyncSubtest::Hub - Hub used by async subtests.

=head1 DESCRIPTION

This is a subclass of L<Test2::Hub::Subtest> used for async subtests.

=head1 SYNOPSIS

You should not use this directly.

=head1 SOURCE

The source code repository for Test2-AsyncSubtest can be found at
F<http://github.com/Test-More/Test2-AsyncSubtest/>.

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
