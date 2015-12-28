package Test2::Formatter;
use strict;
use warnings;

use Test2::API qw/test2_formatter_add/;

my %ADDED;
sub import {
    my $class = shift;
    return if $class eq __PACKAGE__;
    return if $ADDED{$class}++;
    test2_formatter_add($class);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Formatter - Namespace for formatters.

=head1 EXPERIMENTAL RELEASE

This is an experimental release. Using this right now is not recommended.

=head1 DESCRIPTION

This is the namespace for formatters. This is an empty package.

=head1 CREATING FORMATTERS

A formatter is any package or object with a C<write($event, $num)> method.

    package Test2::Formatter::Foo;
    use strict;
    use warnings;

    sub write {
        my $self_or_class = shift;
        my ($event, $assert_num) = @_;
        ...
    }

    1;

The C<write> method is a method, so it either gets a class or instance. The 2
arguments are the C<$event> object it should record, and the C<$assert_num>
which is the number of the current assertion (ok), or the last assertion if
this even is not itself an assertion. The assertion number may be any inyeger 0
or greator, and may be undefined in some cases.

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/Test2/>.

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
