package Test2::Workflow::Util;
use strict;
use warnings;

use Scalar::Util qw/reftype blessed refaddr/;
use Carp qw/croak/;
use B();

our @EXPORT_OK = qw/set_sub_name CAN_SET_SUB_NAME rename_anon_sub update_mask/;
use base 'Exporter';

BEGIN {
    local ($@, $!, $SIG{__DIE__});
    my $have_sub_util = eval { require Sub::Util; 1 };
    my $have_sub_name = eval { require Sub::Name; 1 };

    my $set_subname = $have_sub_util ? Sub::Util->can('set_subname') : undef;
    my $subname     = $have_sub_name ? Sub::Name->can('subname')     : undef;

    *set_sub_name = $set_subname || $subname || sub { croak "Cannot set sub name" };

    if($set_subname || $subname) {
        *CAN_SET_SUB_NAME = sub() { 1 };
    }
    else {
        *CAN_SET_SUB_NAME = sub() { 0 };
    }
}

sub rename_anon_sub {
    my ($name, $sub, $caller) = @_;
    $caller ||= caller();

    croak "sub_name requires a coderef as its second argument"
        unless $sub && ref($sub) eq 'CODE';

    my $cobj = B::svref_2object($sub);
    my $orig = $cobj->GV->NAME;
    return unless $orig =~ m/__ANON__$/;
    set_sub_name("${caller}::${name}", $sub);
}

sub update_mask {
    my ($file, $line, $name, $mask) = @_;

    no warnings 'once';
    my $masks = \%Trace::Mask::MASKS;
    use warnings 'once';

    # Get existing ref, if any
    my $ref = $masks->{$file}->{$line}->{$name};

    # No ref, easy!
    return $masks->{$file}->{$line}->{$name} = {%$mask}
        unless $ref;

    # Merge new mask into old
    %$ref = (%$ref, %$mask);
    return;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Workflow::Util - Tools used by Test2 and friends.

=head1 *** EXPERIMENTAL ***

This distribution is experimental, anything can change at any time!

=head1 DESCRIPTION

Collection of tools used by L<Test2-Workflow>.

=head1 EXPORTS

All exports are optional, you must specify subs to import.

=over 4

=item $bool = CAN_SET_SUB_NAME()

True if it is possible to set a sub name.

=item set_sub_name($name, $coderef)

When L<Sub::Name> or L<Sub::Util> are installed, this will be an alias to the
sub name setting function from one or the other. If neither are installed then
this will be a sub that throws an exception.

If setting the sub name is something nice, but not strictly necessary, you can
use this conditionally with C<CAN_SET_SUB_NAME()>.

    use Test2::Util qw/CAN_SET_SUB_NAME set_sub_name/;
    set_sub_name('foo', \&sub) if CAN_SET_SUB_NAME();

=item rename_anon_sub($name, $sub)

=item rename_anon_sub($name, $sub, \@caller)

Rename a sub, but only if it is anonymous.

=item update_mask($file, $line, $sub, {...})

This sets masking behavior in accordance with L<Trace::Mask>. This will have no
effect on anything that does not honor L<Trace::Mask>.

=back

=head1 SOURCE

The source code repository for Test2-Workflow can be found at
F<http://github.com/Test-More/Test-Workflow/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
