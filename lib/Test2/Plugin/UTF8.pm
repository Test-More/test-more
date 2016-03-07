package Test2::Plugin::UTF8;
use strict;
use warnings;

our $VERSION = '0.000021';

use Test2::API qw{
    test2_add_callback_post_load
    test2_stack
};

sub import {
    my $class = shift;

    # Load and import UTF8 into the caller.
    require utf8;
    utf8->import;

    # Set STDERR and STDOUT
    binmode(STDERR, ':utf8');
    binmode(STDOUT, ':utf8');

    # Set the output formatters to use utf8
    test2_add_callback_post_load(sub {
        my $stack = test2_stack;
        $stack->top; # Make sure we have at least 1 hub

        my $warned = 0;
        for my $hub ($stack->all) {
            my $format = $hub->format || next;

            unless ($format->can('encoding')) {
                warn "Could not apply UTF8 to unknown formatter ($format)\n" unless $warned++;
                next;
            }

            $format->encoding('utf8');
        }
    });
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Plugin::UTF8 - Test2 plugin that enables utf8.

=head1 DESCRIPTION

When used, this plugin will turn on the utf8 pragma, set STDERR and STDOUT to
use utf8, and update the Test2 output formatter to use utf8.

=head1 SYNOPSIS

    use Test2::Plugin::UTF8;

This is the same as

    use utf8;
    BEGIN {
        require Test2::Tools::Core;
        Test2::Tools::Core::set_encoding('utf8');
        binmode(STDERR, ':utf8');
        binmode(STDOUT, ':utf8');
    }

=head1 NOTES

This module sets output handles to have the ':utf8' output layer. Some might
prefer ':encoding(utf-8)' which is more strict about verifying characters.
There is a debate about wether or not encoding to utf8 from perl internals can
ever fail, so it may not matter. This was also chosen because the alternative
causes threads to segfault, see
L<perlbug 3193|https://rt.perl.org/Public/Bug/Display.html?id=31923>.

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

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut