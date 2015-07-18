package Test::Stream::DeepCheck;
use strict;
use warnings;

use Scalar::Util qw/blessed reftype looks_like_number/;
use Carp qw/confess croak/;

use Test::Stream::DeepCheck::State;
use Test::Stream::DeepCheck::Check;
use Test::Stream::DeepCheck::Array;
use Test::Stream::DeepCheck::Hash;
use Test::Stream::DeepCheck::Object;
use Test::Stream::DeepCheck::Object::Array;
use Test::Stream::DeepCheck::Object::Hash;

use Test::Stream::Block;
use Test::Stream::DebugInfo;

use Test::Stream::Context qw/context/;
use Test::Stream::Util qw/try/;

use Test::Stream::Exporter;
default_exports qw{
    strict_compare relaxed_compare
    array hash
    check
    field elem
};
exports qw{
    filter end
    meta call
    object hash_object array_object
    STRUCT
    build_object
    convert
};
no Test::Stream::Exporter;

sub strict_compare($$;$$) {
    my ($got, $want, $name, $diag_sub) = @_;
    my $ctx = context();
    my $state = Test::Stream::DeepCheck::State->new(strict => 1, debug => $ctx->debug);

    $want = convert($want, $ctx->debug, 1);
    my $ok = $want->verify($got, $state);
    my $zebra = 1;
    my $diag = $ok ? undef : [
        $state->render_diag(),
        $diag_sub ? $diag_sub->($got, grep {$zebra = !$zebra} @{$state->path}) : (),
    ];
    $ctx->ok($ok, $name, $diag);
    $ctx->release;
    return $ok;
}

sub relaxed_compare($$;$$) {
    my ($got, $want, $name, $diag_sub) = @_;
    my $ctx = context();
    my $state = Test::Stream::DeepCheck::State->new(strict => 0, debug => $ctx->debug);

    $want = convert($want, $ctx->debug, 0);
    my $ok = $want->verify($got, $state);
    my $zebra = 1;
    my $diag = $ok ? undef : [
        $state->render_diag(),
        $diag_sub ? $diag_sub->($got, grep {$zebra = !$zebra} @{$state->path}) : (),
    ];
    $ctx->ok($ok, $name, $diag);
    $ctx->release;
    return $ok;
}

sub convert {
    confess "Argument is required" unless @_;
    my ($want, $debug, $strict, $seen) = @_;

    return Test::Stream::DeepCheck::Check->new(
        debug => $debug,
        op    => '!defined',
        val   => $want,
    ) unless defined $want;

    my $ref = ref($want) || return Test::Stream::DeepCheck::Check->new(
        debug => $debug,
        op    => (looks_like_number($want) && !$strict) ? '==' : 'eq',
        val   => $want
    );

    if (blessed($want)) {
        return $want if $want->isa('Test::Stream::DeepCheck::Check');
        return $want if $want->isa('Test::Stream::DeepCheck::Meta');
    }

    my $reft = reftype($want);
    return Test::Stream::DeepCheck::Check->new(op => '=~', val => $want, debug => $debug)
        if ($reft eq 'REGEXP' || $ref eq 'Regexp') && !$strict;

    # Treat a codeblock as a custom check outside of is_deeply.
    return Test::Stream::DeepCheck::Check->new(op => $want, debug => $debug)
        if $reft eq 'CODE' && !$strict;

    $seen ||= {};

    if ($reft eq 'HASH') {
        return $seen->{$want} if $seen->{$want};
        my $hash = Test::Stream::DeepCheck::Hash->new(debug => $debug);
        $seen->{$want} = $hash;
        $hash->add_field(
            $_, convert($want->{$_}, $debug, $strict, $seen),
        ) for sort keys %$want;
        return $hash;
    }

    if ($reft eq 'ARRAY') {
        return $seen->{$want} if $seen->{$want};
        my $array = Test::Stream::DeepCheck::Array->new(debug => $debug);
        $array->add_element(
            convert($_, $debug, $strict, $seen),
        ) for @$want;
        $array->end($debug->frame);
        $seen->{$want} = $array;
        return $array;
    }

    return Test::Stream::DeepCheck::Check->new(op => '==', val => $want, debug => $debug);
}

my @STRUCTS;

sub STRUCT { @STRUCTS ? $STRUCTS[-1] : undef }

sub hash_object(&)  { build_object('Test::Stream::DeepCheck::Object::Hash',  @_) }
sub array_object(&) { build_object('Test::Stream::DeepCheck::Object::Array', @_) }
sub object(&)       { build_object('Test::Stream::DeepCheck::Object',        @_) }

sub build_object {
    my ($class, $code, $caller) = @_;
    $caller ||= [caller(1)];
    my $block = Test::Stream::Block->new(coderef => $code, caller => $caller);

    my $obj = $class->new(
        _builder => 1,
        debug    => Test::Stream::DebugInfo->new(
            frame => [$block->package, $block->file, $block->start_line, $caller->[3]],
        ),
    );
    push @STRUCTS => $obj;

    # The 1; is not needed by try, but is used to ensure the code is called in
    # a void context.
    my ($ok, $err) = try { $code->($obj); 1 };
    pop @STRUCTS;
    die $err unless $ok;

    warn "Object build completed with no fields or method calls, codeblock from lines " . $block->start_line . " -> " . $caller->[2] . "\n"
        unless @{$obj->methods} || @{$obj->fields};

    $obj->set__builder(0);
    return $obj;
}

sub array(&) {
    my $code   = shift;
    my @caller = caller;
    my $block  = Test::Stream::Block->new(coderef => $code, caller => \@caller);

    my $array = Test::Stream::DeepCheck::Array->new(
        _builder => 1,
        debug    => Test::Stream::DebugInfo->new(
            frame => [$block->package, $block->file, $block->start_line, $caller[3]],
        ),
    );
    push @STRUCTS => $array;

    # The 1; is not needed by try, but is used to ensure the code is called in
    # a void context.
    my ($ok, $err) = try { $code->($array); 1 };
    pop @STRUCTS;
    die $err unless $ok;

    warn "Array build completed with no elements, codeblock from lines " . $block->start_line . " -> " . $caller[2] . "\n"
        unless @{$array->elements};

    $array->set__builder(0);
    return $array;
}

sub hash(&) {
    my $code   = shift;
    my @caller = caller;
    my $block  = Test::Stream::Block->new(coderef => $code, caller => \@caller);

    my $hash = Test::Stream::DeepCheck::Hash->new(
        _builder => 1,
        debug    => Test::Stream::DebugInfo->new(
            frame => [$block->package, $block->file, $block->start_line, $caller[3]],
        ),
    );
    push @STRUCTS => $hash;

    # The 1; is not needed by try, but is used to ensure the code is called in
    # a void context.
    my ($ok, $err) = try { $code->($hash); 1 };
    pop @STRUCTS;
    die $err unless $ok;

    warn "Hash build completed with no fields, codeblock from lines " . $block->start_line . " -> " . $caller[2] . "\n"
        unless @{$hash->fields};

    $hash->set__builder(0);
    return $hash;
}

sub check($;$) {
    my ($op, $val) = @_;
    my @caller = caller;
    return Test::Stream::DeepCheck::Check->new(
        op    => $op,
        val   => $val,
        debug => Test::Stream::DebugInfo->new(frame => \@caller),
    );
}

sub meta($$;$) {
    my ($name, $op, $val) = @_;

    croak "meta() should only ever be called in a void context"
        if defined wantarray;

    my $meta = $STRUCTS[-1];
    croak "meta() was called with no build is on the stack!"
        unless $meta;

    croak "meta() was called for an invalid build object!"
        unless $meta->isa('Test::Stream::DeepCheck::Meta');

    my @caller = caller;
    my $check  = Test::Stream::DeepCheck::Check->new(
        _builder => 1,
        op       => $op,
        val      => $val,
        debug    => Test::Stream::DebugInfo->new(frame => \@caller),
    );

    $meta->add_meta($name, $check);
}

sub filter(&) {
    my $code = shift;
    croak "filter {} should only ever be called in a void context"
        if defined wantarray;

    my $meta = $STRUCTS[-1];
    croak "meta() was called with no build is on the stack!"
        unless $meta;

    my @caller = caller;
    return $meta->filter($code, \@caller) if $meta->can('filter');
    croak "filter() was called for an invalid build object!";
}

sub end() {
    croak "end() should only ever be called in a void context"
        if defined wantarray;

    my $meta = $STRUCTS[-1];
    croak "end() was called with no build is on the stack!"
        unless $meta;

    my @call = caller;
    return $meta->end(\@call) if $meta->can('end');
    croak "end() was called for an invalid build object!";
}

sub field($$) {
    my ($key, $val) = @_;

    croak "field() should only ever be called in a void context"
        if defined wantarray;

    my $hash = $STRUCTS[-1];
    croak "field() was called with no build is on the stack!"
        unless $hash;

    croak "field() was called but the top of the build stack is not a hash!"
        unless $hash->isa('Test::Stream::DeepCheck::Hash');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = convert($val, $dbg);

    $check->set__builder(1);

    $hash->add_field($key, $check);
}

sub elem($) {
    my ($val) = @_;

    croak "elem() should only ever be called in a void context"
        if defined wantarray;

    my $array = $STRUCTS[-1];
    croak "field() was called with no build is on the stack!"
        unless $array;

    croak "field() was called but the top of the build stack is not a array!"
        unless $array->isa('Test::Stream::DeepCheck::Array');

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = convert($val, $dbg);

    $check->set__builder(1);

    $array->add_element($check);
}

sub call($$;$) {
    my $name = shift;
    my $val  = pop;
    my $args = shift;

    croak "call() should only ever be called in a void context"
        if defined wantarray;

    my $obj = $STRUCTS[-1];
    croak "call() was called with no build on the stack!"
        unless $obj;

    croak "call() was called but the top of the build stack is not an object check!"
        unless $obj->isa('Test::Stream::DeepCheck::Object');

    my ($meth, $wrap);
    if (ref $name) {
        $meth = $name;
    }
    elsif ($name =~ s/^([{\[])(.*)[\}\]]$/$2/) {
        $wrap = $1;
        $meth = $2;
    }
    else {
        $meth = $name;
    }

    my @caller = caller;
    my $dbg    = Test::Stream::DebugInfo->new(frame => \@caller);
    my $check  = convert($val, $dbg);
    $check->set__builder(1);

    $obj->add_method(
        method => $meth,
        check  => $check,
        args   => $args,
        wrap   => $wrap,
    );
}

1;

__END__



=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck - Tools for comparing deep datastructures

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

=head1 SYNOPSIS

    use Test::Stream::DeepCheck;

    my $reg = qr/aaa/;
    strict_compare(
        {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
        {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
        "Match strict"
    );

    relaxed_compare(
        {foo => 1, bar => [ 'a' ], baz => { a => 1, b => 'ignored' }, reg => 'aaa', extra => 'not checked'},
        {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
        "Match relaxed"
    );

Using the other exports for better debugging:

    strict_compare(
        {foo => 1, bar => [ 'a' ], baz => { a => 1 }, reg => $reg},
        hash {
            field foo => 1;
            field bar => array {
                elem 'a';
            };
            field baz => hash {
                field a => 1;
            };
            field reg => $reg;
        },
        'Missed one'
    );

The benefit of this more verbose form is that each check you list record the
line number where you made it. This allows the debugging message to tell you
the file and line number of the exact part of the structure that failed.

Here is one that fails

    # This will fail becuase of bad => 'oops' and bad2 => 1
    strict_compare(
        {foo => 1, bar => [ 'a' ], baz => { a => 1, bad => 'oops', bad2 => 1 }, reg => $reg},
        hash {                    # This is line 76
            field foo => 1;
            field bar => array {
                elem 'a';
            };
            field baz => hash {   # This is like 81.
                field a => 1;
            };
            field reg => $reg;
        },
        'Missed one'
    );

The diag from this will be:

    # Failed test 'Missed one'
    # at t/Test-Stream-DeepCheck.t line 86.
    # Path: $_->{'baz'}->{'bad', 'bad2'}
    # Failed Check: Expected no more fields, got 'bad', 'bad2'
    # t/Test-Stream-DeepCheck.t
    # 76 {
    # 81   'baz': {
    # --     'bad', 'bad2'

Line 86 is listed as the main failure, this is due to how perl reports line
numbers for function calls where arguments extend across multiple lines. We
also list lines 76 and 81 to direct you to the place that actually saw the
failure. You might notice that these lines do not suffer the same line number
problem as the main function, this is because they take codeblock as argument,
we are able to find the correct line number by inspecting the coderef.

=head1 EXPORTS

Not all tools are exported by default. Use '-all' to import everything. If you
want the defaults and just a couple others use '-default' and a list of extras.

    use Test::Stream::DeepCheck '-all';

or

    use Test::Stream::DeepCheck '-default', qw/filter end/;

You can also rename some subs on import:

    use Test::Stream::DeepCheck filter => {-as => 'baleen'};

The following are exported by default (See next sections for usage details):

=over 4

=item strict_compare

=item relaxed_compare

=item array

=item hash

=item check

=item field

=item elem

=back

The following are not exported by default (See next sections for usage
details):

=over 4

=item filter

=item end

=item meta

=item call

=item object

=item hash_object

=item array_object

=item STRUCT

=item build_object

=item convert

=back

=head2 ASSERTIONS

=over 4

=item strict_compare($got, $want, $name, $diag_callback)

This function is made to work like C<is_deeply()> from L<Test::More>.

This compares the data structure in C<$got> to the datastructure in C<$want>.
C<$want> can be a regular reference to a nested datastructure, or it can be a
structure produced using other functions in this library to give you more
control and better debugging.

The strict form will alert you if there are any extra (unspecified) keys in
your hashes, or extra elements in your arrays. When a regex or reference is
encountered in C<$got> the SAME reference should be in C<$want>. All field
checks use C<"$a" eq "$b"> to check for a match, unless they are references in
which case C<==> is used.

You may also provide a coderef as C<$diag_callback>. This coderef will recieve
C<$got> as its first argument, and the keys/indexes used to traverse to the
point of failure. Anything returned from the callback will be added as a
diagnostics message.

=item relaxed_compare($got, $want, $name, $diag_callback)

This is the same as C<strict_compare()> except that it is more liberal in what
it expects. It will only check hash keys specified in C<$want> extra keys in
C<$got> are ignored. Arrays built using C<array { ... }> will ignore extra
elements in C<$got>. If C<$want> has a hashref the equivilent path in C<$got>
will be checked against the regex. Coderefs in C<$want> will be assumed to be
checks that return true or false when called with the value from C<$got> as an
argument. Finally, if both sides look like numbers C<==> will be used instead
of C<eq> to compare them.

You may also provide a coderef as C<$diag_callback>. This coderef will recieve
C<$got> as its first argument, and the keys/indexes used to traverse to the
point of failure. Anything returned from the callback will be added as a
diagnostics message.

=back

=head2 DEFINING STRUCTURES

These can be used to declare datastructures. Using these allows for better
debugging than simply providing a vanilla datastructure. This also gives you
more control using things like C<filter { ... }>.

=over 4

=item $check = array { ... }

Used to build an array check.

Within the array builder codeblock you should use C<elem()> to add elements.
You can also use C<check()> to add more finely controlled checks. C<meta()> can
be used to add checks against the array itself as opposed to its elements.

For relaxed tests this check will ignore elements after the last element checks
you specify. To avoid this behavior use C<end()> to tell the array that there
should be no remaining elements.

B<Note> C<meta()> checks are all run at once, in the order they are defined,
BEFORE any element checks are run.

=item $check = hash { ... }

Same as C<array { ... }> except it defines a hash. Instead of C<elem()> you
should use C<field> to define key/value pairs. C<end()> can be used to make the
hash strictly enforce the number of keys that exist. C<meta()> can still be
used to run checks against the array itself instead of its keys and values.

B<Note> C<meta()> checks are all run at once, in the order they are defined,
BEFORE any field checks are run. Keys will be checked in the order you specify
them.

=item $check = object { ... }

Same as C<hash { ... }> and C<array { ... }> but the check expects a blessed
reference (of any reftype). You should not use C<field()> or C<elem()> on basic
objects, instead you use C<call()> to define methods to call, and what you
expect them to return.

C<meta()> may still be used to define checks against the object itself instead
of its methods.

=item $check = hash_object { ... }

This is a subclass of both the hash and object checks. This lets you use
C<meta()>, C<field()> and C<call()> checks.

B<Note> Checks are run int he following order: Meta, Hash, Object.

=item $check = array_object { ... }

This is a subclass of both the array and object checks. This lets you use
C<meta()>, C<elem()> and C<call()> checks.

B<Note> Checks are run in the following order: Meta, Hash, Object.

=back

=head2 DEFINING CHECKS

=over 4

=item meta($name, $op)

=item meta($name, $op, $val)

Add a meta-check to the current build, it may be a hash, array, or object.
C<$name> is the name of the meta-check for use in debugging. C<$op> can be any
operator known to L<Test::Stream::DeepCheck::Check>.

This function can only be called in void context, and there must be a parent
build (array, hash, object, etc).

=item $check = check($op)

=item $check = check($op, $val)

This quickly builds an L<Test::Stream::DeepCheck::Check> object for you. This
is useful for maing very specific checks of fields or method return values:

    hash_object {
        field foo => check('==', 123.456);
        call  bar => check('eq', 'flubber');
    }

=item field $name => $check

Add a key/value check to the current hash build. Throws an exception if called
in a non-void context. Throws an exception if there is no current build, or if
the current build is not a hash.

    hash {
        field foo => 'FOO';
        field bar => check ...;
        field baz => hash { ... };
    }

=item elem $check

Add a check to the current array build. Throws an exception if called in a
non-void context. Throws an exception if called with no current build, or a
build that is not an array.

    array {
        elem 1;
        elem 'foo';
        elem hash { ... };
    }

=item call $method => $check

=item call "[$method]" => $check

=item call "{$method}" => $check

This is used to check the return value of a method call on the object being
checked. The first argument must be a method name, optionally wrapped with
'[...]' or '{...}'. The wrapping serves to help you check methods that return
more than one value, you can specify that the return should be wrapped in a
hashref or arrayref.

    object {
        call 'foo' => 'FOO';
        call 'foo' => check ...;
        call '[things]' => array { ... };
        call '{lookup}' => hash  { ... };
    }

=back

=head2 OTHER

=over 4

=item filter { grep { ... } @_ }

This works on hashes and arrays, it can be used to remove items from the
datastructure we are validating.

    array {
        # Remove all array elements that do not contain an 'x'
        filter { grep { m/x/ } @_ };
        elem 'fox';
        elem 'rox';
        elem 'box';
        end;
    }

The codeblock recieves all remaining elements as arguments, and should return
all the elements that should still be checked.

    hash {
        filter {
            my %all = @_;
            delete $all{x}; # Remove the x field if present
            return %all;
        };
        field foo => 'bar';
        ...
    }

=item end()

Used to note that there should be not more elements or fields depending on if
the build is a hash or an array.

=item $check = convert($want, $debug, $strict, <$seen>)

This is used to convert a value, such as a string, number, hashref, arrayref,
etc, to an L<Test::Stream::DeepCheck::Check> object. This is used internally to
convert regular structures to the validation checks.

The first argument is the value to convert. The second argument must be an
instance of L<Test::Stream::DebugInfo>. The third argument is a boolean that
toggles strict mode on and off. There is a fourth argument that is used
internally for recursive data structures.

=item $check = build_object($class, $coderef, $caller)

This is used to build an object check of the specified class using the provided
coderef.

=item $build = STRUCT()

This can be used to obtain the current build object.

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
