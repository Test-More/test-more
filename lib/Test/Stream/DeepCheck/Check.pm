package Test::Stream::DeepCheck::Check;
use strict;
use warnings;

use Test::Stream::HashBase(
    accessors => [qw/op val debug _run build_diag _neg _builder/],
);

use Test::Stream::DeepCheck::Util qw/yada render_var/;
use Carp qw/confess/;

use Scalar::Util qw/reftype looks_like_number blessed/;

my %OPS = do {
    no warnings qw/numeric uninitialized/;
    (
        '==' => {run => sub { $_[0] == $_[1] }, diag => \&_sym_diag},
        '!=' => {run => sub { $_[0] != $_[1] }, diag => \&_sym_diag},
        '>=' => {run => sub { $_[0] >= $_[1] }, diag => \&_sym_diag},
        '<=' => {run => sub { $_[0] <= $_[1] }, diag => \&_sym_diag},
        '>'  => {run => sub { $_[0] > $_[1] },  diag => \&_sym_diag},
        '<'  => {run => sub { $_[0] < $_[1] },  diag => \&_sym_diag},

        'eq' => {run => sub { "$_[0]" eq "$_[1]" }, diag => \&_str_diag},
        'ne' => {run => sub { "$_[0]" ne "$_[1]" }, diag => \&_str_diag},
        'ge' => {run => sub { "$_[0]" ge "$_[1]" }, diag => \&_str_diag},
        'le' => {run => sub { "$_[0]" le "$_[1]" }, diag => \&_str_diag},
        'gt' => {run => sub { "$_[0]" gt "$_[1]" }, diag => \&_str_diag},
        'lt' => {run => sub { "$_[0]" lt "$_[1]" }, diag => \&_str_diag},

        '=~' => {run => sub { $_[0] =~ $_[1] }, diag => \&_reg_diag, validate => \&_validate_regex},
        '!~' => {run => sub { $_[0] !~ $_[1] }, diag => \&_reg_diag, validate => \&_validate_regex},

        '!' => {run => sub { !$_[0] }, diag => \&_one_diag, neg => 1},

        'defined' => {run => sub { defined($_[0]) }, diag => \&_one_diag, neg => 1},

        'can'  => {run => sub { $_[0]->can($_[1]) },  diag => \&_meth_diag, neg => 1},
        'isa'  => {run => sub { $_[0]->isa($_[1]) },  diag => \&_meth_diag, neg => 1},
        'does' => {run => sub { $_[0]->does($_[1]) }, diag => \&_meth_diag, neg => 1},
        'blessed' => {run => sub { blessed($_[0]) eq $_[1] }, diag => \&_func_diag, neg => 1},
        'reftype' => {run => sub { reftype($_[0]) eq $_[1] }, diag => \&_func_diag, neg => 1},
    );
};

sub register_op {
    my ($name, %def) = @_;
    confess "operator '$name' already defined" if $OPS{$name};

    confess "'run' is required, and must be a coderef"
        unless $def{run} && ref($def{run}) && reftype($def{run}) eq 'CODE';

    confess "'diag' is required, and must be a coderef"
        unless $def{diag} && ref($def{diag}) && reftype($def{diag}) eq 'CODE';

    confess "'validate' must be a coderef"
        if $def{validate} && (!ref($def{validate}) || reftype($def{validate}) ne 'CODE');

    $OPS{$name} = \%def;
}

sub init {
    my $self = shift;
    confess "the debug attribute is required"
        unless $self->{+DEBUG};
    my $op = $self->{+OP} || confess "op is a required attribute";

    my $rtype = reftype($op) || '';
    if ($rtype eq 'CODE') {
        $self->{+OP}   = 'custom';
        $self->{+_RUN}  = $op;
        $self->{+BUILD_DIAG} ||= \&_cus_diag;
        return;
    }

    my $neg = 0;
    my $def = $OPS{$op};
    if (!$def && $op =~ m/^!(.+)$/) {
        $def = $OPS{$1};
        $neg = 1;
    }

    confess "'$op' is not a known operator for " . __PACKAGE__
        unless $def && (!$neg || $def->{neg});

    $self->{+_RUN}  = $def->{run};
    $self->{+BUILD_DIAG} = $def->{diag};
    $self->{+_NEG}  = $neg;

    my $validate = $def->{validate} || return;
    $validate->($op, $self->{+VAL});
}

sub verify {
    my $self = shift;
    my ($got) = @_;
    my $bool = $self->{+_RUN}->($got, $self->{+VAL});
    return $self->{+_NEG} ? !$bool : $bool;
}

sub diag {
    my $self = shift;
    my ($got) = @_;

    $got = yada() unless @_;

    return $self->{+BUILD_DIAG}->($self->{+OP}, $got, $self->{+VAL});
}

sub _sym_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got);
    $want = render_var($want);

    my $short = "$got $op $want";
    return $short if length($short) <= 40;
    return "... $op ...\n  Expected: $want\n       Got: $got";
}

sub _str_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got, 1);
    $want = render_var($want, 1);

    my $short = "$got $op $want";
    return $short if length($short) <= 40;
    return "... $op ...\n  Expected: $want\n       Got: $got";
}

sub _reg_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got, 1);
    $want = render_var($want);

    my $short = "$got $op $want";
    return $short if length($short) <= 40;
    my $help = $op eq '!~' ? 'Matches' : 'Does not match';
    return "... $op ...\n  $got\n  $help $want";
}

sub _one_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got);

    "$op $got";
}

sub _func_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got);
    $want = render_var($want, 1);

    "$op($got) eq $want";
}

sub _meth_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got);
    $want = render_var($want, 1);

    $op =~ s/^(!)//;
    my $neg = $1 || '';

    "$neg$got\->$op($want)";
}

sub _cus_diag {
    my ($op, $got, $want) = @_;
    $got  = render_var($got);
    $want = render_var($want, 1);

    my $short = "$op($got, $want)";
    return $short if length($short) <= 40;
    return "$op(\n    $got,\n    $want\n  )"
}

sub _validate_regex {
    my ($op, $got) = @_;
    return if $got && ref $got && ref $got eq 'Regexp';
    $got = render_var($got);
    confess "val must be a regex when op is '$op', got: $got";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Check - Library for comparisons and other simple
checks with diagnostics.

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

This library is used by several Test::Stream tools, particularily those that do
deep datastructure checks. This library may be useful to test tool authors, but
will not be useful to people just looking to write tests.

=head1 SYNOPSIS

    use Test::Stream::DeepCheck::Check;
    use Test::Stream::Context qw/context/;

    sub my_tool {
        my ($got, $want, $name) = @_;

        my $ctx = context();
        my $check = Test::Stream::DeepCheck::Check->new(
            debug => $ctx->debug,
            op    => '>=',
            val   => $want,
        );

        # Do the actual check
        my $bool = $check->verify($got);

        # The diagnostics are only used by ok() when $bool is false.
        $ctx->ok($bool, $name, [$check->diag($got)]);

        # return the boolean
        return $bool;
    }

=head1 METHODS

=over 4

=item $check = $class->new(op => $op, val => $want, debug => $debug)

This is used to create a new instance.

=item $bool = $check->verify($got)

This will return a true or false value depening on if $got matches what we
expect for the given operator and desired value.

=item $diag = $check->diag()

=item $diag = $check->diag($got)

This will return a diagnostics string with information about what went wrong.
If you provide a C<$got> value then the diagnostics message will show it,
otherwise it will show '...'.

=back

=head1 OPERATORS

Operators need to be registered with the module before they can be used. This
is the safest way to run these checks. Test::More originally just used
C<eval "$got $op $want">, which had significant pitfalls (such as using '#' in
the operator leading to false passes).

=head2 BUILT-IN OPERATORS

=over 4

=item '=='

=item '!='

=item '>='

=item '<='

=item '>'

=item '<'

These are the numeric comparison operators. C<==> and C<!=> will also work for
references.

=item 'eq'

=item 'ne'

=item 'ge'

=item 'le'

=item 'gt'

=item 'lt'

These are the string comparison operators.

=item '=~'

=item '!~'

These compare the stringin <$got> to the pattern provided as
C<< val => $pattern >> during construction.

=item '!'

Simple operator, passes if C<$got> is false. The C<val> passed in during
construction is not used.

You can prefix this operator with C<!> to invert the check:

    $check = $class->new( op => '!!', ... );

This will result in a check that C<$got> is true.

=item 'defined'

Simple operator, passes if C<$got> is defined. The C<val> passed in during
construction is not used.

You can prefix this operator with C<!> to invert the check:

    $check = $class->new( op => '!defined', ... );

This will result in a check that C<$got> is not defined.

=item 'can'

Check C<< $got->can($want) >>. $want is passed in as C<val> during
construction.

=item 'isa'

Check C<< $got->isa($want) >>. $want is passed in as C<val> during
construction.

=item 'does'

Check C<< $got->does($want) >>. $want is passed in as C<val> during
construction.

=item 'blessed'

Check C<blessed($got) eq $want>. $want is passed in as C<val> during
construction.

=item 'reftype'

Check C<reftype($got) eq $want>. $want is passed in as C<val> during
construction.

=back

=head2 REGISTERING NEW OPERATORS

You can add custom operators:

    Test::Stream::DeepCheck::Check::register_op(
        '=!=' => (
            # The actual check
            run => sub {
                my ($got, $want) = @_;
                return $got != $want;
            },

            # Produce diagnostics messages
            diag => sub {
                my ($op, $got, $want);
                return "...";
            },

            # Used to validate the '$want' value. This is optional.
            validate => sub {
                my ($op, $want) = @_;
                die unless $want...;
            },

            # Set this to true if you want to allow '!' prefixing to negate the check.
            neg => 1,
        ),
    );

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
