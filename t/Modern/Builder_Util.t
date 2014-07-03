use strict;
use warnings;

use Test::More 'modern';

{
    package My::Example;
    use Test::Builder::Util qw/
        import export exports accessor accessors delta deltas export_to transform
        atomic_delta atomic_deltas new
    /;

    export foo => sub { 'foo' };
    export 'bar';
    exports qw/baz bat/;

    sub bar { 'bar' }
    sub baz { 'baz' }
    sub bat { 'bat' }

    accessor apple => sub { 'fruit' };

    accessors qw/x y z/;

    delta number => 5;
    deltas qw/alpha omega/;

    transform add5 => sub { $_[1] + 5 };
    transform add6 => '_add6';

    sub _add6 { $_[1] + 6 }

    atomic_delta a_number => 5;
    atomic_deltas qw/a_alpha a_omega/;

    package My::Consumer;
    My::Example->import(qw/foo bar baz bat/);
}

can_ok(
    'My::Example',
    qw/
        import export accessor accessors delta deltas export_to transform
        atomic_delta atomic_deltas new

        bar baz bat
        apple
        x y z
        number
        alpha omega
        add5 add6
        a_number
        a_alpha a_omega
    /
);

can_ok('My::Consumer', qw/foo bar baz bat/);

is(My::Consumer->$_, $_, "Simple sub $_") for qw/foo bar baz bat/;

my $one = My::Example->new(x => 1, y => 2, z => 3);
isa_ok($one, 'My::Example');
is($one->x, 1, "set at construction");
is($one->y, 2, "set at construction");
is($one->z, 3, "set at construction");

is($one->x(5), 5, "set value");
is($one->x(), 5, "kept value");

is($one->number, 5, "default");
is($one->number(2), 7, "Delta add the number");
is($one->number(-2), 5, "Delta add the number");

is($one->alpha, 0, "default");
is($one->alpha(2), 2, "Delta add the number");
is($one->alpha(-2), 0, "Delta add the number");

is($one->add5(3), 8, "transformed");
is($one->add6(3), 9, "transformed");

# XXX TODO: Test these in a threaded environment
is($one->a_number, 5, "default");
is($one->a_number(2), 7, "Delta add the number");
is($one->a_number(-2), 5, "Delta add the number");

is($one->a_alpha, 0, "default");
is($one->a_alpha(2), 2, "Delta add the number");
is($one->a_alpha(-2), 0, "Delta add the number");

done_testing;
