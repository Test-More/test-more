package Test2::Bundle::More;
use strict;
use warnings;

our $VERSION = '0.000041';

use Test2::Plugin::ExitSummary;

use Test2::Tools::Basic qw{
    ok pass fail skip todo diag note
    plan skip_all done_testing bail_out
};

use Test2::Tools::ClassicCompare qw{
    is is_deeply isnt like unlike cmp_ok
};

use Test2::Tools::Class qw/can_ok isa_ok/;
use Test2::Tools::Subtest qw/subtest_streamed/;

BEGIN {
    *BAIL_OUT = \&bail_out;
    *subtest  = \&subtest_streamed;
}

our @EXPORT = qw{
    ok pass fail skip todo diag note
    plan skip_all done_testing BAIL_OUT

    is isnt like unlike is_deeply cmp_ok

    isa_ok can_ok

    subtest
};
use base 'Exporter';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Bundle::More - ALMOST a drop-in replacement for Test::More.

=head1 DESCRIPTION

This bundle is intended to be a (mostly) drop-in replacement for
L<Test::More>. See L<"KEY DIFFERENCES FROM Test::Simple"> for details.

=head1 SYNOPSYS

    use Test2::Bundle::More;

    ok(1, "pass");

    ...

    done_testing;

=head1 PLUGINS

This loads L<Test2::Plugin::ExitSummary>.

=head1 TOOLS

These are from L<Test2::Tools::Basic>. See L<Test2::Tools::Basic> for details.

=over 4

=item ok($bool, $name)

=item pass($name)

=item fail($name)

=item skip($why, $count)

=item $todo = todo($why)

=item diag($message)

=item note($message)

=item plan($count)

=item skip_all($why)

=item done_testing()

=item BAIL_OUT($why)

=back

These are from L<Test2::Tools::ClassicCompare>. See
L<Test2::Tools::ClassicCompare> for details.

=over 4

=item is($got, $want, $name)

=item isnt($got, $donotwant, $name)

=item like($got, qr/match/, $name)

=item unlike($got, qr/mismatch/, $name)

=item is_deeply($got, $want, "Deep compare")

=item cmp_ok($got, $op, $want, $name)

=back

These are from L<Test2::Tools::Class>. See L<Test2::Tools::Class> for details.

=over 4

=item isa_ok($thing, @classes)

=item can_ok($thing, @subs)

=back

This is from L<Test2::Tools::Subtest>, it is called C<subtest_streamed()> in
that package.

=over 4

=item subtest $name => sub { ... }

=back

=head1 KEY DIFFERENCES FROM Test::Simple

=over 4

=item You cannot plan at import.

THIS WILL B<NOT> WORK:

    use Test2::Bundle::Simple tests => 5;

Instead you must plan in a seperate statement:

    use Test2::Bundle::Simple;
    plan 5;

=item You have 3 subs imported for use in planning

Use C<plan($count)>, C<skip_all($reason)>, or C<done_testing()> for your
planning.

=item isa_ok accepts different arguments

C<isa_ok> in Test::More was:

    isa_ok($thing, $isa, $alt_thing_name);

This was very inconsistent with tools like C<can_ok($thing, @subs)>.

In Test2::Bundle::More, C<isa_ok()> takes a C<$thing> and a list of C<@isa>.

    isa_ok($thing, $class1, $class2, ...);

=back

=head2 THESE FUNCTIONS AND VARIABLES HAVE BEEN REMOVED

=over 4

=item $TODO

See C<todo()>.

=item use_ok()

=item require_ok()

These are not necessary.

=item todo_skip()

Not necessary.

=item eq_array()

=item eq_hash()

=item eq_set()

Discouraged in Test::More.

=item explain()

This started a fight between Test developers, who may now each write their own
implementations in L<Test2>. (See explain in L<Test::Most> vs L<Test::More>.
Hint: Test::Most wrote it first, then Test::More added it, but broke
compatability).

=item new_ok()

Not necessary.

=back

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<http://github.com/Test-More/Test2-Suite/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
