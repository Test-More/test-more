use Test::Stream -V1, -Tester;
use Test::Stream::Workflow::Unit;

my $one = Test::Stream::Workflow::Unit->new(
    name       => 'foo',
    package    => __PACKAGE__,
    file       => __FILE__,
    start_line => __LINE__,
    end_line   => __LINE__,
    type       => 'group',
);
isa_ok($one, 'Test::Stream::Workflow::Unit');

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

$one = Test::Stream::Workflow::Unit->new(
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

my $unit = Test::Stream::Workflow::Unit->new(
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

{
    local $unit->meta->{skip} = "this is a skip";
    my $ctx = $unit->context;
    is($ctx->debug->skip, 'this is a skip', "skip is set");
}

done_testing;
