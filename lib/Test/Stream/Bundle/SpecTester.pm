package Test::Stream::Bundle::SpecTester;
use strict;
use warnings;

use Test::Stream::Bundle;

sub plugins {
    return (qw/-Tester Spec/);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Bundle::SpecTester - Spec + the Tester bundle

=head1 EXPERIMENTAL CODE WARNING

C<This module is still EXPERIMENTAL>. Test-Stream is now stable, but this
particular module is still experimental. You are still free to use this module,
but you have been warned that it may change in backwords incompatible ways.
This message will be removed from this modules POD once it is considered
stable.

=head1 DESCRIPTION

This bundle includes the L<Test::Stream::Bundle::Tester> bundle and the
L<Test::Stream::Plugin::Spec> plugin.

=head1 SYNOPSIS

    use Test::Stream Core, -SpecTester;

    tests stuff => sub {
        is(
            intercept { ok(1, "pass") },
            array {
                event Ok => sub {
                    call pass => T();
                    call name => 'pass';
                };
                end;
            },
            "Intercepted an event"
        );
    }

    done_testing;

=head1 INCLUDED PLUGINS AND BUNDLES

=head2 Test::Stream::Plugin::Spec

Provides SPEC workflow tools.

=head2 Test::Stream::Bundle::Tester

Imports tools useful for testing test tools.

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
