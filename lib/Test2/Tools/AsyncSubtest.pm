package Test2::Tools::AsyncSubtest;
use strict;
use warnings;

use Test2::AsyncSubtest;
use Test2::API qw/context/;
use Carp qw/croak/;

our @EXPORT = qw/subtest_start subtest_finish subtest_run/;
use base 'Exporter';

sub subtest_start {
    my ($name) = @_;

    croak "The first argument to subtest_start should be a subtest name"
        unless $name;

    my $subtest = Test2::AsyncSubtest->new(name => $name);

    return $subtest;
}

sub subtest_run {
    my $subtest = shift;
    my ($code) = @_;

    my $ctx = context();

    my $ok = $subtest->run(trace => $ctx->trace, $code);

    $ctx->release;

    return $ok;
}

sub subtest_finish {
    my $subtest = shift;
    my $ctx = context();

    $subtest->finish(trace => $ctx->trace);

    my $e = $ctx->build_event(
        'Subtest',
        $subtest->event_data,
    );

    $ctx->hub->send($e);
    $ctx->failure_diag($e) unless $e->pass;

    my @extra_diag = $subtest->diagnostics;
    $ctx->diag($_) for @extra_diag;

    $ctx->release;

    return $e->pass;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Tools::AsyncSubtest - Tools for writing async subtests.

=head1 DESCRIPTION

These are tools for writing async subtests. Async subtests are subtests which
can be started and stashed so that they can continue to recieve events while
other events are also being generated.

=head1 SYNOPSYS

    use Test2::Bundle::Extended;
    use Test2::Tools::AsyncSubtest;

    my $ast = subtest_start('ast');

    subtest_run $ast => sub {
        ok(1, "not concurrent A");
    };

    ok(1, "Something else");

    subtest_run $ast => sub {
        ok(1, "not concurrent B");
    };

    ok(1, "Something else");

    subtest_finish($ast);

    done_testing;

=head1 EXPORTS

Everything is exported by default.

=over 4

=item $ast = subtest_start($name)

Create a new async subtest. C<$ast> will be an instance of
L<Test2::AsyncSubtest>.

=item $passing = subtest_run($ast, sub { ... })

Run the provided codeblock from inside the async subtest. This can be called
any number of times, and can be called from any process or thread spawned after
C<$ast> was created.

=item $passing = subtest_finish($ast)

This will finish the async subtest and send the final L<Test2::Event::Subtest>
event to the current hub.

B<Note:> This must be called in the thread/process that created the Async
Subtest.

=back

=head1 NOTES

=over 4

=item Async Subtests are always buffered.

=back

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
