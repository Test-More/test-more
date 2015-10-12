package Test::Stream::Plugin::Compare;
use strict;
use warnings;

use Test::Stream::Exporter;
default_exports qw/is like/;
exports qw{
    match mismatch validator
    hash array object meta
    in_set not_in_set check_set
    item field call prop check
    end filter_items
    T F D DNE FDNE
    event
    exact_ref
};
no Test::Stream::Exporter;

use Carp qw/croak/;
use Scalar::Util qw/reftype blessed/;

use Test::Stream::Compare qw/-all/;
use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/rtype/;

use Test::Stream::Compare::Array;
use Test::Stream::Compare::Custom;
use Test::Stream::Compare::Event;
use Test::Stream::Compare::Hash;
use Test::Stream::Compare::Meta;
use Test::Stream::Compare::Object;
use Test::Stream::Compare::Pattern;
use Test::Stream::Compare::Ref;
use Test::Stream::Compare::Regex;
use Test::Stream::Compare::Scalar;
use Test::Stream::Compare::Set;
use Test::Stream::Compare::Value;
use Test::Stream::Compare::Wildcard;

sub is($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&strict_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub like($$;$@) {
    my ($got, $exp, $name, @diag) = @_;
    my $ctx = context();

    my @caller = caller;

    my $delta = compare($got, $exp, \&relaxed_convert);

    if ($delta) {
        $ctx->ok(0, $name, [$delta->table, @diag]);
    }
    else {
        $ctx->ok(1, $name);
    }

    $ctx->release;
    return !$delta;
}

sub meta(&)   { build('Test::Stream::Compare::Meta',   @_) }
sub hash(&)   { build('Test::Stream::Compare::Hash',   @_) }
sub array(&)  { build('Test::Stream::Compare::Array',  @_) }
sub object(&) { build('Test::Stream::Compare::Object', @_) }

my $FDNE = Test::Stream::Compare::Custom->new(code => sub { $_ ? 0 : 1 }, name => 'FALSE', operator => 'FALSE() || !exists');
my $DNE = Test::Stream::Compare::Custom->new(code => sub { my %p = @_; $p{exists} ? 0 : 1 },          name => '<DOES NOT EXIST>', operator => '!exists');
my $F   = Test::Stream::Compare::Custom->new(code => sub { my %p = @_; $p{got}    ? 0 : $p{exists} }, name => 'FALSE',            operator => 'FALSE()');
my $T = Test::Stream::Compare::Custom->new(code => sub { $_         ? 1 : 0 }, name => 'TRUE',    operator => 'TRUE()');
my $D = Test::Stream::Compare::Custom->new(code => sub { defined $_ ? 1 : 0 }, name => 'DEFINED', operator => 'DEFINED()');

sub T()    { $T }
sub F()    { $F }
sub D()    { $D }
sub DNE()  { $DNE }
sub FDNE() { $FDNE }

sub strict_convert  { convert($_[0], 1) }
sub relaxed_convert { convert($_[0], 0) }

sub exact_ref($) {
    my @caller = caller;
    return Test::Stream::Compare::Ref->new(
        file  => $caller[1],
        lines => [$caller[2]],
        input => $_[0],
    );
}

sub match($) {
    my @caller = caller;
    return Test::Stream::Compare::Pattern->new(
        file    => $caller[1],
        lines   => [$caller[2]],
        pattern => $_[0],
    );
}

sub mismatch($) {
    my @caller = caller;
    return Test::Stream::Compare::Pattern->new(
        file    => $caller[1],
        lines   => [$caller[2]],
        negate  => 1,
        pattern => $_[0],
    );
}

sub validator {
    my $code = pop;
    my $cname = pop;
    my $op = pop;

    my @caller = caller;
    return Test::Stream::Compare::Custom->new(
        file     => $caller[1],
        lines    => [$caller[2]],
        code     => $code,
        name     => $cname,
        operator => $op,
    );
}

sub filter_items(&) {
    my $build = get_build() or croak "No current build!";

    croak "'$build' does not support filters"
        unless $build->can('add_filter');

    croak "'filter_items' should only ever be called in void context"
        if defined wantarray;

    $build->add_filter(@_);
}

sub end() {
    my $build = get_build() or croak "No current build!";

    croak "'$build' does not support 'ending'"
        unless $build->can('ending');

    croak "'end' should only ever be called in void context"
        if defined wantarray;

    $build->set_ending(1);
}

sub call($$) {
    my ($name, $expect) = @_;
    my $build = get_build() or croak "No current build!";

    croak "'$build' does not support method calls"
        unless $build->can('add_call');

    croak "'call' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    $build->add_call(
        $name,
        Test::Stream::Compare::Wildcard->new(
            expect => $expect,
            file   => $caller[1],
            lines  => [$caller[2]],
        ),
    );
}

sub prop($$) {
    my ($name, $expect) = @_;
    my $build = get_build() or croak "No current build!";

    croak "'$build' does not support meta-checks"
        unless $build->can('add_prop');

    croak "'prop' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    $build->add_prop(
        $name,
        Test::Stream::Compare::Wildcard->new(
            expect => $expect,
            file   => $caller[1],
            lines  => [$caller[2]],
        ),
    );
}

sub item($;$) {
    my @args   = @_;
    my $expect = pop @args;

    my $build = get_build() or croak "No current build!";

    croak "'$build' does not support array item checks"
        unless $build->can('add_item');

    croak "'item' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    push @args => Test::Stream::Compare::Wildcard->new(
        expect => $expect,
        file   => $caller[1],
        lines  => [$caller[2]],
    );

    $build->add_item(@args);
}

sub field($$) {
    my ($name, $expect) = @_;

    my $build = get_build() or croak "No current build!";

    croak "'$build' does not support hash field checks"
        unless $build->can('add_field');

    croak "'field' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    $build->add_field(
        $name,
        Test::Stream::Compare::Wildcard->new(
            expect => $expect,
            file   => $caller[1],
            lines  => [$caller[2]],
        ),
    );
}

sub check($) {
    my ($check) = @_;

    my $build = get_build() or croak "No current build!";

    croak "'$build' is not a check-set"
        unless $build->can('add_check');

    croak "'check' should only ever be called in void context"
        if defined wantarray;

    my @caller = caller;
    my $wc = Test::Stream::Compare::Wildcard->new(
        expect => $check,
        file   => $caller[1],
        lines  => [$caller[2]],
    );

    $build->add_check($wc);
}

sub check_set  { return _build_set('all'  => @_) }
sub in_set     { return _build_set('any'  => @_) }
sub not_in_set { return _build_set('none' => @_) }

sub _build_set {
    my $redux = shift;
    my ($builder) = @_;
    my $btype = reftype($builder) || '';

    my $set;
    if ($btype eq 'CODE') {
        $set = build('Test::Stream::Compare::Set', $builder);
        $set->set_builder($builder);
    }
    else {
        $set = Test::Stream::Compare::Set->new(checks => [@_]);
    }

    $set->set_reduction($redux);
    return $set;
}

sub event($;$) {
    my ($intype, $spec) = @_;

    my @caller = caller;

    croak "type is required" unless $intype;

    my $type;
    if ($intype =~ m/^\+(.*)$/) {
        $type = $1;
    }
    else {
        $type = "Test::Stream::Event::$intype";
    }

    my $event;
    if (!$spec) {
        $event = Test::Stream::Compare::Event->new(
            etype => $intype,
            file  => $caller[1],
            lines => [$caller[2]],
        );
    }
    elsif (!ref $spec) {
        croak "'$spec' is not a valid event specification"
    }
    elsif (reftype($spec) eq 'CODE') {
        $event = build('Test::Stream::Compare::Event', $spec);
        $event->set_etype($intype),
        $event->set_builder($spec);
    }
    else {
        my $refcheck = Test::Stream::Compare::Hash->new(
            inref => $spec,
            file  => $caller[1],
            lines => [$caller[2]],
        );
        $event = Test::Stream::Compare::Event->new(
            refcheck => $refcheck,
            file     => $caller[1],
            lines    => [$caller[2]],
            etype => $intype,
        );
    }

    $event->add_prop('blessed' => $type);

    return $event if defined wantarray;

    my $build = get_build() or croak "No current build!";
    $build->add_item($event);
}

sub convert {
    my ($thing, $strict) = @_;

    if ($thing && blessed($thing) && $thing->isa('Test::Stream::Compare')) {
        return $thing unless $thing->isa('Test::Stream::Compare::Wildcard');
        my $newthing = convert($thing->expect, $strict);
        $newthing->set_builder($thing->builder) unless $newthing->builder;
        $newthing->set_file($thing->_file)      unless $newthing->_file;
        $newthing->set_lines($thing->_lines)    unless $newthing->_lines;
        return $newthing;
    }

    my $type = rtype($thing);

    return Test::Stream::Compare::Array->new(inref => $thing, $strict ? (ending => 1) : ())
        if $type eq 'ARRAY';

    return Test::Stream::Compare::Hash->new(inref => $thing, $strict ? (ending => 1) : ())
        if $type eq 'HASH';

    unless ($strict) {
        return Test::Stream::Compare::Pattern->new(pattern => $thing)
            if $type eq 'REGEXP';

        return Test::Stream::Compare::Custom->new(code => $thing)
            if $type eq 'CODE';
    }

    return Test::Stream::Compare::Regex->new(input => $thing)
        if $type eq 'REGEXP';

    if ($type eq 'SCALAR') {
        my $nested = relaxed_convert($$thing);
        return Test::Stream::Compare::Scalar->new(item => $nested)
    }

    return Test::Stream::Compare::Ref->new(input => $thing)
        if $type;

    return Test::Stream::Compare::Value->new(input => $thing);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Plugin::Compare - Tools for comparing deep data structures.

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

Test::More had C<is_deeply()>. This library is the L<Test::Stream> version.
This library can be used to compare data structures. This library goes a step
further though, it provides tools for building a data structure specification
against which you can verify your data. There are both 'strict' and 'relaxed'
versions of the tools.

=head1 SYNOPSIS

    use Test::Stream 'Compare';

    # Hash for demonstration purposes
    my $some_hash = {a => 1, b => 2, c => 3};

    # Strict checking, everything must match
    is(
        $some_hash,
        {a => 1, b => 2, c => 3},
        "The hash we got matches our expectations"
    );

    # Relaxed Checking, only fields we care about are checked, and we can use a
    # regex to approximate a field.
    like(
        $some_hash,
        {a => 1, b => qr/\d+/},
        "'a' is 1, 'b' is an integer, we don't care about 'c'."
    );

=head1 COMPARISON TOOLS

=over 4

=item $bool = is($got, $expect)

=item $bool = is($got, $expect, $name)

=item $bool = is($got, $expect, $name, @diag)

C<$got> is the data structure you want to check. C<$expect> is what you want
C<$got> to look like. C<$name> is an optional name for the test. C<@diag> is
optional diagnostics messages that will be printed to STDERR in event of
failure, they will not be displayed when the comparison is successful. The
boolean true/false result of the comparison is returned.

This is the strict checker. The strict checker requires a perfect match between
C<$got> and C<$expect>. All hash fields must be specfied, all array items must
be present, etc. All non-scalar/hash/array/regex references must be identical
(same memory address). Scalar, hash and array references will be traversed and
compared. Regex references will be compared to see if they have the same
pattern.

    is(
        $some_hash,
        {a => 1, b => 2, c => 3},
        "The hash we got matches our expectations"
    );

The only exception to strictness is when it is given an C<$expect> object that
was built from a specification, in which case the specification determines the
strictness. Strictness only applies to literal values/references that are
provided and converted to a specification for you.

    is(
        $some_hash,
        hash {    # Note: the hash function is not exported by default
            field a => 1;
            field b => match(qr/\d+/);    # Note: The match function is not exported by default
            # Don't care about other fields.
        },
        "The hash comparison is not strict"
    );

This works for both deep and shallow structures. For instance you can use this
to compare 2 strings:

    is('foo', 'foo', "strings match");

B<Note>: This is not the tool to use if you want to check if 2 references are
the same exact reference, use C<ref_is()> from the
L<Test::Stream::Plugin::Core> plugin instead. I<Most> of the time this will
work as well, however there are problems if your reference contains a cyle and
refers back to itself at some point, if this happens an exception will be
thrown to break an otherwise infinite recursion.

=item like($got, $expect)

=item like($got, $expect, $name)

=item like($got, $expect, $name, @diag)

C<$got> is the data structure you want to check. C<$expect> is what you want
C<$got> to look like. C<$name> is an optional name for the test. C<@diag> is
optional diagnostics messages that will be printed to STDERR in event of
failure, they will not be displayed when the comparison is successful. The
boolean true/false result of the comparison is returned.

This is the relaxed checker. This will ignore hash keys or array indexes that
you do not actually specify in your C<$expect> structure. In addition regex and
sub references will be used as validators. If you provide a regex using
C<qr/.../>, the regex itself will be used to validate the corresponding value
in the C<$got> structure. The same is true for coderefs, the value is passed in
as the first argument (and in C<$_>) and the sub should return a boolean value.

    like(
        $some_hash,
        {a => 1, b => qr/\d+/},
        "'a' is 1, 'b' is an integer, we don't care about other fields"
    );

This works for both deep and shallow structures. For instance you can use this
to compare 2 strings:

    like('foo bar', qr/^foo/, "string matches the pattern");

=back

=head2 QUICK CHECKS

B<Note: None of these are exported by default, you need to request them.>

Quick checks are a way to quickly generate a common value specification. These
can be used in structures passed into C<is> and C<like> through the C<$expect>
argument.

Example:

    is($foo, T(), '$foo has a true value');

=over 4

=item $check = T()

This verifies that the value in the corresponding C<$got> structure is
true, any true value will do.

    is($foo, T(), '$foo has a true value');

    is(
        { a => 'xxx' },
        { a => T() },
        "The 'a' key is true"
    );

=item $check = F()

This verifies that the value in the corresponding C<$got> structure is
false, any false value will do, B<but the value must exist>.

    is($foo, F(), '$foo has a false value');

    is(
        { a => 0 },
        { a => F() },
        "The 'a' key is false"
    );

It is important to note that a non-existant value does not count as false, this
check will generate a failing test result:

    is(
        { a => 1 },
        { a => 1, b => F() },
        "The 'b' key is false"
    );

This will produce the following output:

    not ok 1 - The b key is false
    # Failed test "The 'b' key is false"
    # at some_file.t line 10.
    # +------+------------------+-------+---------+
    # | PATH | GOT              | OP    | CHECK   |
    # +------+------------------+-------+---------+
    # | {b}  | <DOES NOT EXIST> | FALSE | FALSE() |
    # +------+------------------+-------+---------+

In perl you can have behavior that is different for a missing key vs a false
key, as such it was decided not to count a completely absent value as false.
See the C<DNE()> shortcut below for checking that a field is missing.

If you want to check for false and/or DNE use the C<FDNE()> check.

=item $check = D()

This is to verify that the value in the C<$got> structure is defined. Any value
other than C<undef> will pass.

This will pass:

    is('foo', D(), 'foo is defined');

This will fail:

    is(undef, D(), 'foo is defined');

=item $check = DNE()

This can be used to check that no value exists. This is useful to check the end
bound of an array, or to check that a key does not exist in a hash.

These pass:

    is(['a', 'b'], ['a', 'b', DNE()], "There is no third item in the array");
    is({a => 1}, {a => 1, b => DNE()}, "The 'b' key does not exist in the hash");

These will fail:

    is(['a', 'b', 'c'], ['a', 'b', DNE()], "No third item");
    is({a => 1, b => 2}, {a => 1, b => DNE()}, "No 'b' key");

=item $check = FDNE()

This is a combination of C<F()> and C<DNE()>. This will pass for a false value,
or a non-existant value.

=back

=head2 VALUE SPECIFICATIONS

B<Note: None of these are exported by default, you need to request them.>

=over 4

=item $check = match qr/.../

Verify that the value matches the regex pattern.

=item $check = mismatch qr/.../

Verify that the value does not match the regex pattern.

=item $check = validator(sub{ ... })

=item $check = validator($NAME => sub{ ... })

=item $check = validator($OP, $NAME, sub{ ... })

The coderef is the only required argument. The coderef should check that the
value is what you expect, it should return a boolean true or false. Optionally
you can specify a name and operator that are used in diagnostics, they are also
provided to the sub itself as named parameters.

Check the value using this sub. The sub gets the value in C<$_>, as well it
recieved the value and several other items as named parameters.

    my $check = validator(sub {
        my %params = @_;

        # These both work:
        my $got = $_;
        my $got = $params{got};

        # Check if a value exists at all
        my $exists = $params{exists}

        # What $OP (if any) did we specify when creating the validator
        my $operator = $params{operator};

        # What name (if any) did we specify when creating the validator
        my $name = $params{name};

        ...

        return $bool;
    }

=item $check = exact_ref($ref)

Check that the value is exactly the same reference as the one provided.

=back

=head2 SET BUILDERS

B<Note: None of these are exported by default, you need to request them.>

=over 4

=item my $check = check_set($check1, $check2, ...)

Check that the value matches ALL of the specified checks.

=item my $check = in_set($check1, $check2, ...)

Check that the value matches 1 OR MORE of the specified checks.

=item not_in_set($check1, $check2, ...)

Check that the value DOES NOT match ANY of the specified checks.

=item check $thing

Check that the value matches the specified thing.

=back

=head2 HASH BUILDER

B<Note: None of these are exported by default, you need to request them.>

    $check = hash {
        field foo => 1;
        field bar => 2;

        # Ensure the 'baz' keys does not even exist in the hash.
        field baz => DNE();

        # Ensure the key exists, but is set to undef
        field bat => undef;

        # Any check can be used
        field boo => $check;

        ...

        end(); # optional, enforces that no other keys are present.
    };

=over 4

=item $check = hash { ... }

This is used to define a hash check.

=item field $NAME => $VAL

=item field $NAME => $CHECK

Specify a field check. This will check the hash key specified by C<$NAME> and
ensure it matches the value in C<$VAL>. You can put any valid check in C<$VAL>,
such as the result of another call to C<array { ... }>, C<DNE()>, etc.

B<Note:> This function can only be used inside a hash builder sub, and must be
called in void context.

=item end()

Enforce that no keys are found in the hash other than those specified. This is
essentually the 'use strict' of a hash check. This can be used anywhere in the
hash builder, though typically it is placed at the end.

=item DNE()

This is a handy check that can be used with C<field()> to ensure that a field
(D)oes (N)not (E)xist.

    field foo => DNE();

=back

=head2 ARRAY BUILDER

B<Note: None of these are exported by default, you need to request them.>

    $check = hash {
        # Uses the next index, in this case index 0;
        item 'a';

        # Gets index 1 automatically
        item 'b';

        # Specify the index
        item 2 => 'c';

        # We skipped index 3, which means we don't care what it is.
        item 4 => 'e';

        # Gets index 5.
        item 'f';

        # Remove any REMAINING items that contain 0-9.
        filter_items { grep {m/\D/} @_ };

        # Of the remaining items (after the filter is applied) the next one
        # (which is now index 6) should be 'g'.
        item 6 => 'g';

        item 7 => DNE; # Ensure index 7 does not exist.

        end(); # Ensure no other indexes exist.
    };

=over 4

=item $check = array { ... }

=item item $VAL

=item item $CHECK

=item item $IDX, $VAL

=item item $IDX, $CHECK

Add an expected item to the array. If C<$IDX> is not specified it will
automatically calculate it based on the last item added. You can skip indexes,
which means you do not want them to be checked.

You can provide any value to check in C<$VAL>, or you can provide any valid
check object.

B<Note:> Items MUST be added in order.

B<Note:> This function can only be used inside an array builder sub, and must
be called in void context.

=item filter_items { my @remaining = @_; ...; return @filtered }

This function adds a filter, all items remaining in the array from the point
the filter is reached will be passed into the filter sub as arguments, the sub
should return only the items that should be checked.

B<Note:> This function can only be used inside an array builder sub, and must
be called in void context.

=item end()

Enforce that there are no indexes after the last one specified. This will not
force checking of skipped indexes.

=item DNE()

This is a handy check that can be used with C<item()> to ensure that an index
(D)oes (N)not (E)xist.

    item 5 => DNE();

=back

=head2 META BUILDER

B<Note: None of these are exported by default, you need to request them.>

    my $check = meta {
        prop blessed => 'My::Module'; # Ensure value is blessed as our package
        prop reftype => 'HASH';       # Ensure value is a blessed hash
        prop size    => 4;            # Check the number of hash keys
        prop this    => ...;          # Check the item itself
    };

=over 4

=item meta { ... }

Build a meta check

=item prop $NAME => $VAL

=item prop $NAME => $CHECK

Check the property specified by C<$name> against the value or check.

Valid properties are:

=over 4

=item 'blessed'

What package (if any) the thing is blessed as.

=item 'reftype'

Reference type (if any) the thing is.

=item 'this'

The thing itself.

=item 'size'

For array references this returns the number of elements. For hashes this
returns the number of keys. For everything else this returns undef.

=back

=back

=head2 OBJECT BUILDER

B<Note: None of these are exported by default, you need to request them.>

    my $check = object {
        call foo => 1; # Call the 'foo' method, check the result.

        # Call the specified sub-ref as a method on the object, check the
        # result. This is useful for wrapping methods that return multiple
        # values.
        call sub { [ shift->get_list ] } => [...];

        # This can be used to ensure a method does not exist.
        call nope => DNE();

        # Check the hash key 'foo' of the underlying reference, this only works
        # on blessed hashes.
        field foo => 1;

        # Check the value of index 4 on the underlying reference, this only
        # works on blessed arrays.
        item 4 => 'foo';

        # Check the meta-property 'blessed' of the object.
        prop blessed => 'My::Module';

        # Ensure only the specified hash keys or array indexes are present in
        # the underlying hash. Has no effect on meta-property checks or method
        # checks.
        end();
    };

=over 4

=item $check = object { ... }

Specify an object check for use in comparisons.

=item call $METHOD_NAME => $RESULT

=item call $METHOD_NAME => $CHECK

=item call sub { ... }, $RESULT

=item call sub { ... }, $CHECK

Call the specified method (or coderef) and verify the result. The coderef form
us useful if you want to check a method that returns a list as it allows you to
wrap the result in a reference.

    my $ref = sub {
        my $self = shift;
        my @result = $self->get_list;
        return \@result;
    };

    call $ref => [ ... ];

=item field $NAME => $VAL

Works just like it does for hash checks.

=item item $VAL

=item item $IDX, $VAL

Works just like it does for array checks.

=item prop $NAME => $VAL

=item prop $NAME => $CHECK

Check the property specified by C<$name> against the value or check.

Valid properties are:

=over 4

=item 'blessed'

What package (if any) the thing is blessed as.

=item 'reftype'

Reference type (if any) the thing is.

=item 'this'

The thing itself.

=item 'size'

For array references this returns the number of elements. For hashes this
returns the number of keys. For everything else this returns undef.

=back

=item DNE()

Can be used with C<item>, or C<field> to ensure the hash field or array index
does not exist. Can also be used with C<call> to ensure a method does not
exist.

=item end()

Turn on strict array/hash checking, that is ensure that no extra keys/indexes
are present.

=back

=head2 EVENT BUILDER

B<Note: None of these are exported by default, you need to request them.>

Check that we got an event of a specified type:

    my $check = event 'Ok';

Check for details about the event:

    my $check = event Ok => sub {
        # Check for a failure
        call pass => 0;

        # Effective pass after TODO/SKIP are accounted for.
        call effective_pass => 1;

        # Check the diagnostics
        call diag => [ match qr/Failed test foo/ ];

        # Check the file the event reports to
        prop file => 'foo.t';

        # Check the line number the event reports o
        prop line => '42';

        # You can check the todo/skip values as well:
        prop skip => 'broken';
        prop todo => 'fixme';

        # Thread-id and process-id where event was generated
        prop tid => 123;
        prop pid => 123;
    };

You can also provide a fully qualified event package with the '+' prefix:

    my $check = event '+My::Event' => sub { ... }

=over 4

=item $check = event $TYPE;

=item $check = event $TYPE => sub { ... };

This works just like an object builder. In addition to supporting everything
the object check supports, you also have to specify the event type, and many
extra meta-properties are available.

Extra properties are:

=over 4

=item 'file'

File name to which the event reports (for use in diagnostics).

=item 'line'

Line number to which the event reports (for use in diagnostics).

=item 'package'

Package to which the event reports (for use in diagnostics).

=item 'subname'

Sub that was called to generate the event (example: C<ok()>).

=item 'skip'

Set to the skip value if the result was generated by skipping tests.

=item 'todo'

Set to the todo value if TODO was set when the event was generated.

=item 'trace'

The 'at file foo.t line 42' string that will be used in diagnostics.

=item 'tid'

Thread id in which the event was generated.

=item 'pid'

PRocess id in which the event was generated.

=back

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
