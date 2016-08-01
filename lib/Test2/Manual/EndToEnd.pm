package Test2::Manual::EndToEnd;
use strict;
use warnings;

__END__

=head1 NAME

Test2::Manual::EndToEnd - 

=head1 DESCRIPTION

=head1 WHAT HAPPENS WHEN I LOAD THE API?

    use Test2::API qw/context/;

=over 4

=item A singleton instance of Test2::API::Instance is created.

You have no access to this, it is an implementation detail.

=item Several API functions are defined that use the singleton instance.

You can import these functions, or use them directly.

=item Then what?

It waits...

The API intentionally does as little as possible. At this point something can
still change the formatter, load L<Test2::IPC>, or have other global effects
that need to be done before the first L<Test2::API::Context> is created. Once
the first L<Test2::API::Context> is created the API will finish initialization.

See L</"WHAT HAPPENS WHEN I AQUIRE A CONTEXT?"> for more information.

=back

=head1 WHAT HAPPENS WHEN I USE A TOOL?

This section covers the basic workflow all tools such as C<ok()> must follow.

    sub ok($$) {
        my ($bool, $name) = @_;

        my $ctx = context();

        my $event = $ctx->send_event('Ok', pass => $bool, name => $name);

        ...

        $ctx->release;
        return $bool;
    }

    ok(1, "1 is true");

=over 4

=item A tool function is run.

    ok(1, "1 is true");

=item The tool acquires a context object.

    my $ctx = context();

See L</"WHAT HAPPENS WHEN I AQUIRE A CONTEXT?"> for more information.

=item The tool uses the context object to create, send, and return events.

See L</"WHAT HAPPEND WHEN I SEND AN EVENT?"> for more information.

    my $event = $ctx->send_event('Ok', pass => $bool, name => $name);

=item When done the tool MUST release the context.

See L</"WHAT HAPPENS WHEN I RELEASE A CONTEXT?"> for more information.

    $ctx->release();

=item The tool returns.

    return $bool;

=back

=head1 WHAT HAPPENS WHEN I AQUIRE A CONTEXT?

=head1 WHAT HAPPEND WHEN I SEND AN EVENT?

=head1 WHAT HAPPENS WHEN I RELEASE A CONTEXT?

=head1 SEE ALSO

L<Test2::Manual> - PRimary index of the manual.

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

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
