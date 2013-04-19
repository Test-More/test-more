package TB2::CanLoad;

require TB2::Mouse;
use TB2::Mouse::Role;
with 'TB2::CanTry';

use Carp;

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::CanLoad - load modules without affecting global variables

=head1 SYNOPSIS

    package My::Thing;

    use TB2::Mouse;
    with "TB2::CanLoad";

    My::Thing->load("Some::Module");

=head1 DESCRIPTION

Test::Builder2 must be careful to leave the global state of the test
alone.  This especially includes things like $@ and $!.
Unfortunately, a lot of things change them.  C<require> is one of
them.

This module provides C<load> as a safe replacement for C<require>
which does not affect global variables (except the obvious ones like
C<%INC>).

=head3 load

    $class->load($module);

This works like L<require> to load a module, except it will not affect
C<$!> and C<$@> and not trip a C<$SIG{__DIE__}> handler.  Use it
internally in your test module when you want to load a module.

It B<will> die on failure if the $module fails to load in which case
it B<will> set C<$@>.  If you want to trap the failure, see
L<TB2::CanTry>.

=cut

my %Loaded;
sub load {
    my $self   = shift;
    my $module = shift;

    return $Loaded{$module} if $Loaded{$module};

    my $ret = $self->try(sub {
        croak qq['$module' does not look like a module name]
          unless $self->_looks_like_a_module_name($module);

        my $path = $module;
        $path =~ s{::}{/}g;
        $path .= ".pm";

        # Untaint so things like TB2_FORMATTER_CLASS work
        $path =~ m{(.*)};
        $path = $1;

        require $path;
    }, die_on_fail => 1);

    $Loaded{$module} = $ret;

    return $ret;
}


sub _looks_like_a_module_name {
    my $self = shift;
    my $module = shift;

    return $module =~ /^\w+(::\w+)*$/
}


=head1 SEE ALSO

L<TB2::CanTry>

=cut

no TB2::Mouse;
no TB2::Mouse::Role;

1;
