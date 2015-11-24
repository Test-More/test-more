use Test::Stream -V1, -Tester, Class => ['Test::Stream::Workflow::Unit'];

my $one = CLASS->new(
    name       => 'foo',
    package    => __PACKAGE__,
    file       => __FILE__,
    start_line => __LINE__,
    end_line   => __LINE__,
    type       => 'group',
);
isa_ok($one, CLASS);

can_ok($one, qw{
    do_post
    add_post
    add_modify
    add_buildup
    add_primary
    add_teardown
});

my $fake = sub { 'fake' };
for my $it (qw/post modify buildup primary teardown/) {
    my $add = "add_$it";
    is($one->$it, undef, "not set yet ($it)");
    $one->$add($fake);
    $one->$add($fake);
    is($one->$it, [$fake, $fake], "added a hash and pushed to it twice ($it)");
}

$one = CLASS->new(
    name       => 'foo',
    package    => __PACKAGE__,
    file       => __FILE__,
    start_line => __LINE__,
    end_line   => __LINE__,
    type       => 'group',
);
my @stuff;
$one->add_post(sub { push @stuff => $_[0], 'post!' });
ok(!@stuff, "no post yet");
$one->do_post;
is(\@stuff, [$one, 'post!'], "Post ran");

my $unit = CLASS->new(
    name       => 'my unit',
    package    => 'Some::Package',
    file       => 'Some/Package.t',
    start_line => 10,
    end_line   => 100,
    meta       => {},
);

my $is_canon;
like(
    intercept {
        local $unit->meta->{todo} = "this is todo";
        my $ctx = $unit->context;
        $ctx->ok(0, "You Fail!");
    },
    array {
        event Ok => {
            pass           => 0,
            effective_pass => 1,
            diag           => [qr/TODO/],
        };
    },
    "got a todo event"
);

like(
    dies { CLASS->new() },
    qr/name is a required attribute/,
    "Need to specify some attrs"
);

$one = CLASS->new(
    name       => 'foo',
    package    => 'XXX',
    file       => 'XXX.pm',
    start_line => 20,
    end_line   => 'EOF',
    type       => 'group',
);

ok(!$one->contains(19), "does not have line 19");
ok($one->contains(10000), "EOF");
ok($one->contains(20), "does have line 20");
ok($one->contains(40), "does have line 40");
ok($one->contains(30), "does have line 30");

ok($one->contains("XXX.pm 30"), "has line 30 of the file");
ok(!$one->contains("XXY.pm 30"), "no line 30 of the file");

ok($one->contains("foo"), "has the name");
ok(!$one->contains("fob"), "does not have the name");
ok(!$one->contains("bar"), "does not have the name");

my $two = CLASS->new(
    name       => 'bar',
    package    => 'XXX',
    file       => 'XXX.pm',
    start_line => 20,
    end_line   => 30,
    type       => 'group',
);
ok(!$two->contains(41), "does not have line 41");
ok($two->contains("bar"), "has the name");

$one->add_primary($two);
ok($one->contains("foo"), "has the name");
ok($one->contains("bar"), "found child");


$one->set_end_line(25);
is($one->start_line, 20, "start line is 20");
is($one->end_line, 25, "start line is 20");

$two->set_start_line(5);
$two->set_end_line(30);

$one->adjust_lines;
is($one->start_line, 4, "start line adjusted to be 1 before childs");
is($one->end_line, 31, "end line adjusted to be 1 after childs");

$two->set_end_line('EOF');
$one->adjust_lines;
is($one->end_line, 'EOF', "EOF works");

done_testing;
