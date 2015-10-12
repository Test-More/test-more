package Test::Stream::Compare::Pattern;
use strict;
use warnings;

use Test::Stream::Compare;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare',
    accessors => [qw/pattern negate/],
);

use Carp qw/croak/;

sub init {
    my $self = shift;

    croak "'pattern' is a required attribute" unless $self->{+PATTERN};

    $self->SUPER::init();
}

sub name { shift->{+PATTERN} . "" }
sub operator { shift->{+NEGATE} ? '!~' : '=~' }

sub verify {
    my $self = shift;
    my %params = @_;
    my ($got, $exists) = @params{qw/got exists/};

    return 0 unless $exists;
    return 0 if ref $got;
    return 0 unless defined($got);

    return $got !~ $self->{+PATTERN}
        if $self->{+NEGATE};

    return $got =~ $self->{+PATTERN};
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::Pattern - Use a pattern to validate values in a deep
comparison.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This allows you to use a regex to validate a value in a deep comparison.
Sometimes a value just needs to look right, it may not need to be exact. An
example is a memory address, it might change from run to run.

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
