package Test2::Compare;
use strict;
use warnings;

our $VERSION = '0.000056';

use Scalar::Util qw/blessed/;
use Test2::Util qw/try/;
use Test2::Util::Ref qw/rtype/;

use Carp qw/croak/;

our @EXPORT_OK = qw{
    compare
    get_build push_build pop_build build
    strict_convert relaxed_convert
};
use base 'Exporter';

sub compare {
    my ($got, $check, $convert) = @_;

    $check = $convert->($check);

    return $check->run(
        id      => undef,
        got     => $got,
        exists  => 1,
        convert => $convert,
        seen    => {},
    );
}

my @BUILD;

sub get_build  { @BUILD ? $BUILD[-1] : undef }
sub push_build { push @BUILD => $_[0] }

sub pop_build {
    return pop @BUILD if @BUILD && $_[0] && $BUILD[-1] == $_[0];
    my $have = @BUILD ? "$BUILD[-1]" : 'undef';
    my $want = $_[0]  ? "$_[0]"      : 'undef';
    croak "INTERNAL ERROR: Attempted to pop incorrect build, have $have, tried to pop $want";
}

sub build {
    my ($class, $code) = @_;

    my @caller = caller(1);

    die "'$caller[3]\()' should not be called in void context in $caller[1] line $caller[2]\n"
        unless defined(wantarray);

    my $build = $class->new(builder => $code, called => \@caller);

    push @BUILD => $build;
    my ($ok, $err) = try { $code->($build); 1 };
    pop @BUILD;
    die $err unless $ok;

    return $build;
}

sub strict_convert  { convert($_[0], 1) }
sub relaxed_convert { convert($_[0], 0) }

my $CONVERT_LOADED = 0;
sub convert {
    my ($thing, $strict) = @_;

    unless($CONVERT_LOADED) {
        require Test2::Compare::Array;
        require Test2::Compare::Base;
        require Test2::Compare::Custom;
        require Test2::Compare::DeepRef;
        require Test2::Compare::Hash;
        require Test2::Compare::Pattern;
        require Test2::Compare::Ref;
        require Test2::Compare::Regex;
        require Test2::Compare::Scalar;
        require Test2::Compare::String;
        require Test2::Compare::Undef;
        require Test2::Compare::Wildcard;
        $CONVERT_LOADED = 1;
    }

    return Test2::Compare::Undef->new()
        unless defined $thing;

    if ($thing && blessed($thing) && $thing->isa('Test2::Compare::Base')) {
        return $thing unless $thing->isa('Test2::Compare::Wildcard');
        my $newthing = convert($thing->expect, $strict);
        $newthing->set_builder($thing->builder) unless $newthing->builder;
        $newthing->set_file($thing->_file)      unless $newthing->_file;
        $newthing->set_lines($thing->_lines)    unless $newthing->_lines;
        return $newthing;
    }

    my $type = rtype($thing);

    return Test2::Compare::Array->new(inref => $thing, $strict ? (ending => 1) : ())
        if $type eq 'ARRAY';

    return Test2::Compare::Hash->new(inref => $thing, $strict ? (ending => 1) : ())
        if $type eq 'HASH';

    unless ($strict) {
        return Test2::Compare::Pattern->new(
            pattern       => $thing,
            stringify_got => 1,
        ) if $type eq 'REGEXP';

        return Test2::Compare::Custom->new(code => $thing)
            if $type eq 'CODE';
    }

    return Test2::Compare::Regex->new(input => $thing)
        if $type eq 'REGEXP';

    if ($type eq 'SCALAR') {
        my $nested = convert($$thing, $strict);
        return Test2::Compare::Scalar->new(item => $nested);
    }

    return Test2::Compare::DeepRef->new(input => $thing)
        if $type eq 'REF';

    return Test2::Compare::Ref->new(input => $thing)
        if $type;

    # is() will assume string and use 'eq'
    return Test2::Compare::String->new(input => $thing);
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Compare - Test2 extension for writing deep comparison tools.

=head1 DESCRIPTION

This library is the driving force behind deep comparison tools such as
C<Test2::Tools::Compare::is()> and
C<Test2::Tools::ClassicCompare::is_deeply()>.

=head1 SYNOPSIS

    package Test2::Tools::MyCheck;

    use Test2::Compare::MyCheck;
    use Test2::Compare qw/compare/;

    sub MyCheck {
        my ($got, $exp, $name, @diag) = @_;
        my $ctx = context();

        my $delta = compare($got, $exp, \&convert);

        if ($delta) {
            $ctx->ok(0, $name, [$delta->table, @diag]);
        }
        else {
            $ctx->ok(1, $name);
        }

        $ctx->release;
        return !$delta;
    }

    sub convert {
        my $thing = shift;
        return $thing if blessed($thing) && $thing->isa('Test2::Compare::MyCheck');

        return Test2::Compare::MyCheck->new(stuff => $thing);
    }

See L<Test2::Compare::Base> for details about writing a custom check.

=head1 EXPORTS

=over 4

=item $delta = compare($got, $expect, \&convert)

This will compare the structures in C<$got> with those in C<$expect>, The
convert sub should convert vanilla structures inside C<$expect> into checks.
If there are differences in the structures they will be reported back as an
L<Test2::Compare::Delta> tree.

=item $build = get_build()

Get the current global build, if any.

=item push_build($build)

Set the current global build.

=item $build = pop_build($build)

Unset the current global build. This will throw an exception if the build
passed in is different from the current global.

=item build($class, sub { ... })

Run the provided codeblock with a new instance of C<$class> as the current
build. Returns the new build.

=item $check = strict_convert($thing)

Convert C<$thing> to an L<Test2::Compare::*> object. This will behave strictly
which means:

=over 4

=item Array bounds will be checked when this object is used in a comparison

=item No unexpected hash keys can be present.

=item Sub references will be compared as refs (IE are these sub refs the same ref?)

=item Regexes will be compared directly (IE are the regexes the same?)

=back

=item $compare = relaxed_convert($thing)

Convert C<$thing> to an L<Test2::Compare::*> object. This will be relaxed which
means:

=over 4

=item Array bounds will not be checked when this object is used in a comparison

=item Unexpected hash keys can be present.

=item Sub references will be run to verify a value.

=item Values will be checked against any regexes provided.

=back

=back

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

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
