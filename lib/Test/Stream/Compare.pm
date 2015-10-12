package Test::Stream::Compare;
use strict;
use warnings;

use Test::Stream::Util qw/try sub_info/;
use Test::Stream::Delta;

use Carp qw/confess croak/;
use Scalar::Util qw/blessed/;

use Test::Stream::Exporter;
export compare => sub {
    my ($got, $check, $convert) = @_;

    $check = $convert->($check);

    return $check->run(
        id      => undef,
        got     => $got,
        exists  => 1,
        convert => $convert,
        seen    => {},
    );
};

sub MAX_CYCLES() { 75 }

my @BUILD;

export get_build  => sub { @BUILD ? $BUILD[-1] : undef };
export push_build => sub { push @BUILD => $_[0] };

export pop_build => sub {
    return pop @BUILD if @BUILD && $_[0] && $BUILD[-1] == $_[0];
    my $have = @BUILD ? "$BUILD[-1]" : 'undef';
    my $want = $_[0]  ? "$_[0]"      : 'undef';
    croak "INTERNAL ERROR: Attempted to pop incorrect build, have $have, tried to pop $want";
};

export build => sub {
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
};
no Test::Stream::Exporter;

use Test::Stream::HashBase(
    accessors => [qw/builder _file _lines _info called/]
);

*set_lines = \&set__lines;
*set_file  = \&set__file;

sub init {
    my $self = shift;
    $self->{_lines} = delete $self->{lines} if exists $self->{lines};
    $self->{_file}  = delete $self->{file}  if exists $self->{file};
}

sub file {
    my $self = shift;
    return $self->{+_FILE} if $self->{+_FILE};

    if ($self->{+BUILDER}) {
        $self->{+_INFO} ||= sub_info($self->{+BUILDER});
        return $self->{+_INFO}->{file};
    }
    elsif ($self->{+CALLED}) {
        return $self->{+CALLED}->[1];
    }

    return undef;
}

sub lines {
    my $self = shift;
    return $self->{+_LINES} if $self->{+_LINES};

    if ($self->{+BUILDER}) {
        $self->{+_INFO} ||= sub_info($self->{+BUILDER});
        return $self->{+_INFO}->{lines} if @{$self->{+_INFO}->{lines}};
    }
    if ($self->{+CALLED}) {
        return $self->{+CALLED}->[2];
    }
    return [];
}

use Test::Stream::Delta;
sub delta_class { 'Test::Stream::Delta' }

sub deltas { () }
sub got_lines { () }

sub operator { '' }
sub verify   { confess "unimplemented" }
sub name     { confess "unimplemented" }

sub render {
    my $self = shift;
    return $self->name;
}

sub run {
    my $self = shift;
    my %params = @_;

    my $id      = $params{id};
    my $convert = $params{convert} or confess "no convert sub provided";
    my $seen    = $params{seen} ||= {};

    $params{exists} = exists $params{got} ? 1 : 0
        unless exists $params{exists};

    my $exists = $params{exists};
    my $got = $exists ? $params{got} : undef;

    # Prevent infinite cycles
    if ($got && ref $got) {
        die "Cycle detected in comparison, aborting"
            if $seen->{$got} && $seen->{$got} >= MAX_CYCLES;
        $seen->{$got}++;
    }

    my $ok = $self->verify(%params);
    my @deltas = $ok ? $self->deltas(%params) : ();

    $seen->{$got}-- if $got && ref $got;

    return if $ok && !@deltas;

    return $self->delta_class->new(
        verified => $ok,
        id       => $id,
        got      => $got,
        check    => $self,
        children => \@deltas,
        $exists ? () : (dne => 'got'),
    );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare - Tools for comparing data structures.

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This library is the driving force behind C<is()>. The library is the base class
for several comparison classes that allow for deep structure comparisons.

=head1 SYNOPSIS

=head2 FOR COMPARISON CLASSES

    package Test::Stream::Compare::MyCheck;
    use strict;
    use warnings;

    use Test::Stream::Compare;
    use Test::Stream::HashBase(
        base => 'Test::Stream::Compare',
        accessors => [qw/stuff/],
    );

    sub name { 'STUFF' }

    sub operator {
        my $self = shift;
        my ($got) = @_;
        return 'eq';
    }

    sub verify {
        my $self = shift;
        my $params = @_;

        # Always check if $got even exists, this will be false if no value at
        # all was recieved. (as opposed to a $got of 'undef' or '0' which are
        # valid meaning this field will be true).
        return 0 unless $params{exists};

        my $got = $params{got};

        return $got eq $self->stuff;
    }

=head2 FOR PLUGINS

    package Test::Stream::Plugin::MyCheck;

    use Test::Stream::Compare::MyCheck;

    use Test::Stream::Compare qw/compare get_build push_build pop_build build/;

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
        return $thing if blessed($thing) && $thing->isa('Test::Stream::Compare::MyCheck');

        return Test::Stream::Compare::MyCheck->new(stuff => $thing);
    }

=head1 EXPORTS

=over 4

=item $delta = compare($got, $expect, \&convert)

This will compare the structures in C<$got> with those in C<$expect>, The
convert sub should convert vanilla structures inside C<$expect> into checks.
If there are differences in the structures they will be reported back as an
L<Test::Stream::Delta> tree.

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

=back

=head1 METHODS

Some of these must be overriden, others can be.

=over 4

=item $dclass = $check->delta_class

Returns the delta subclass that should be used. By default
L<Test::Stream::Delta> is used.

=item @deltas = $check->deltas(id => $id, exists => $bool, got => $got, convert => \&convert, seen => \%seen)

Should return child deltas.

=item @lines = $check->got_lines($got)

This is your chance to provide line numbers for errors in the C<$got>
structure.

=item $op = $check->operator()

=item $op = $check->operator($got)

Returns the operator that was used to compare the check with the recieved data
in C<$got>. If there was no value for got then there will be no arguments,
undef will only be an argument if undef was seen in C<$got>, this is how you
can tell the difference between a missing value and an undefined one.

=item $bool = $check->verify(id => $id, exists => $bool, got => $got, convert => \&convert, seen => \%seen)

Return true if there is a shallow match, that is both items are arrayrefs, both
items are the same string or same number, etc. This should not look deep, deep
checks are done in C<< $check->deltas() >>.

=item $name = $check->name

Get the name of the check.

=item $display = $check->render

What should be displayed in a table for this check, usually the name or value.

=item $delta = $check->run(id => $id, exists => $bool, got => $got, convert => \&convert, seen => \%seen)

This is where the checking is done, first a shallow check using
C<< $check->verify >>, then checking C<< $check->deltas() >>. C<\%seen> is used
to prevent cycles.

=back

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
