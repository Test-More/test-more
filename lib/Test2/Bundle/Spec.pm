package Test2::Bundle::Spec;
use strict;
use warnings;

use Test2::IPC;

require Import::Into;
require Test2::Bundle::Extended;
require Test2::Tools::Spec;

sub import {
    my $class  = shift;
    my @caller = caller;
    my $target = {
        package => $caller[0],
        file    => $caller[1],
        line    => $caller[2],
    };

    Test2::Bundle::Extended->import::into($target, @_);
    Test2::Tools::Spec->import::into($target);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Bundle::Spec - Extended Bundle + IPC + Spec

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

This loads the L<Test2::IPC> module, as well as L<Test2::Bundle::Extended> and
L<Test2::Tools::Spec>.

=head1 SYNOPSIS

    use Test2::Bundle::Spec;

Is the same as:

    use Test2::IPC;
    use Test2::Bundle::Extended;
    use Test2::Tools::Spec;

=head1 SOURCE

The source code repository for Test2-Workflow can be found at
F<http://github.com/Test-More/Test2-Workflow/>.

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
