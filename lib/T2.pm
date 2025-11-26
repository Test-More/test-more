package T2;
use strict;
use warnings;

my $INIT;
my $HANDLE;
sub handle { $HANDLE }

sub import {
    my $class = shift;
    my ($handle) = @_;

    my ($caller, $file, $line) = caller;

    die "The ${ \__PACKAGE__ } namespace has already been initialized (Originally initiated at $INIT->[1] line $INIT->[2]) at $file line $line.\n"
        if $INIT;

    unless ($handle) {
        die "The '$caller' package does not provide a T2 handler at $file line $line.\n"
            unless $caller->can('T2');

        $handle = $caller->T2 or die "Could not get handle via '$caller\->T2()' at $file line $line.\n";
    }

    die "'$handle' is not a Test2::Handle instance at $file line $line.\n"
        unless $handle->isa('Test2::Handle');

    $INIT = [$caller, $file, $line];
    $HANDLE = $handle;

    for my $sym ($HANDLE->HANDLE_SUBS) {
        next if $sym eq 'import';
        next if $sym eq 'handle';

        my $code = $HANDLE->HANDLE_NAMESPACE->can($sym);
        my $proto = prototype($code);

        my $header = defined($proto) ? "sub $sym($proto) {" : "sub $sym {";

        my $line = __LINE__ + 3;
        my $sub = eval <<"        EOT" or die $@;
#line $line ${ \__FILE__ }
$header
    my (\$f) = \@_;
    shift if \$f && "\$f" eq "$class";
    goto &\$code;
};

\\&$sym;
        EOT

        no strict 'refs';
        *$sym = $sub;
    }
}

sub AUTOLOAD {
    my ($this) = @_;

    if ($this) {
        shift if "$this" eq 'T2';
        shift if ref($this) eq 'T2';
    }

    my ($name) = (our $AUTOLOAD =~ m/^(?:.*::)?([^:]+)$/);

    my @caller = caller;
    my $sub = $HANDLE->HANDLE_NAMESPACE->can($name) or die qq{"$name" is not provided by this T2 handle at $caller[1] line $caller[2].\n};
    goto &$sub;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

T2 - Define the L<T2> namespace that can always be used to access functionality
from a Test2 bundle such as L<Test2::V1>.

=head1 DESCRIPTION

If you want a global C<T2> that can be called from anywhere, without needing to
import L<Test2::V1> in every package, you can do that with the L<T2> module.

This defines the L<T2> namespace so you can always call methods on it like
C<< T2->ok(1, "pass") >> and C<< T2->done_testing >>.

=head1 SYNOPSIS

Create a file/package somewhere to initialize it. Only initialize it once!

    package My::Global::T2;

    # Load Test2::V1 (or future bundle)
    # Add any customizations like including extra tools, overriding tools, etc.
    use Test2::V1 ...;

    # Load T2, it will find the T2() handle in the current package and make it global
    use T2;

    #########################################
    # Alternatively you can do this:
    my $handle = Test2::V1::Handle->new(...);
    require T2;
    T2->import($handle);

Now use it somewhere in your code:

    use My::Global::T2;

Now T2 is available from any package

    T2->ok(1, "pass");
    T2->ok(0, "fail");

    T2->done_testing;

B<Note:> In this case T2 is a package name, not a function, so C<< T2() >> will
not work. However you can import L<Test2::V1> into any package providing a T2()
function that will be used preferentially to the L<T2> namespace.

B<Bonus:> You can use the C<T2::tool(...)> form to leverage the original
prototype of the tool.

    T2::is(@foo, 3, "Array has 3 elements");

Without the prototype (method form does not allow prototypes) you would have to
prefix scalar on C<@foo>:

    T2->is(scalar(@foo), 3, "Array matches expections");

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<https://github.com/Test-More/test-more/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
