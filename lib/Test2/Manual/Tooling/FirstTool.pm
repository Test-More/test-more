package Test2::Manual::Tooling::FirstTool;

1;

__END__

=head1 NAME

Test2::Manual::Tooling::FirstTool - Write your first tool with Test2.

=head1 DESCRIPTION

This tutorial will help you write your very first tool by cloning the C<ok()>
tool.

=head1 COMPLETE CODE UP FRONT

    package Test2::Tools::MyOk;
    use strict;
    use warnings;

    use Test2::API qw/context/;

    use base 'Exporter';
    our @EXPORT = qw/ok/;

    sub ok($;$@) {
        my ($bool, $name, @diag) = @_;

        my $ctx = context();

        return $ctx->pass_and_release($name) if $bool;
        return $ctx->fail_and_release($name, @diag);
    }

    1;

=head1 SEE ALSO

L<Test2::Manual> - Primary index of the manual.

=head1 SOURCE

The source code repository for Test2-Manual can be found at
F<http://github.com/Test-More/Test2-Manual/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2017 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
