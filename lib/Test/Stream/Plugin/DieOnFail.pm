package Test::Stream::Plugin::DieOnFail;
use strict;
use warnings;

use Test::Stream::Plugin;
use Test::Stream::Context;

my $LOADED = 0;
sub load_ts_plugin {
    my $class = shift;
    my $caller = shift;
    return if $LOADED++;

    Test::Stream::Context->ON_RELEASE(sub {
        my $ctx = shift;
        return if $ctx->hub->state->is_passing;
        $ctx->throw("(Die On Fail)");
    });
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::DieOnFail - Automatically die on the first test failure.

=head1 EXPERIMENTAL CODE WARNING

C<This module is still EXPERIMENTAL>. Test-Stream is now stable, but this
particular module is still experimental. You are still free to use this module,
but you have been warned that it may change in backwords incompatible ways.
This message will be removed from this modules POD once it is considered
stable.

=head1 DESCRIPTION

This module will die after the first test failure. This will prevent your tests
from continuing. The exception is thrown when the context is released, that is
it will run when the test function you are using, such as C<ok()>, returns;
This gives the tools the ability to output any extra diagnostics they may need.

=head1 SYNOPSIS

    use Test::Stream qw/Core DieOnFail/;

    ok(1, "pass");
    ok(0, "fail");
    ok(1, "Will not run");

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
