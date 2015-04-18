use strict;
use warnings;

use Test::Stream qw/context hook_event_init/;
use Test::More;
use Test::Stream::Tester;

use ok 'Test::Stream::Event';

can_ok('Test::Stream::Event', qw/context created in_subtest/);

my $ok = eval { Test::Stream::Event->new(); 1 };
my $err = $@;
ok(!$ok, "Died");
like($err, qr/No context provided/, "Need context");

{
    package My::MockEvent;
    use Test::Stream::Event(
        accessors => [qw/foo bar baz/],
    );
}

can_ok('My::MockEvent', qw/foo bar baz/);
isa_ok('My::MockEvent', 'Test::Stream::Event');

my $one = My::MockEvent->new(context => 'fake');

sub foo {
    my $ctx = context();
    $ctx->ok(1, "pass");
    $ctx->diag("xxx");
    $ctx->note("yyy");
}

events_are(
    intercept {
        my $x = 0;
        hook_event_init {
            my $self = shift;
            $self->stash->{foo} = "Num: " . $x++;
        };
        foo();
    },
    check {
        event ok => {
            name => 'pass',
            pass => 1,
            stash => sub {check_stash(@_, 0)},
        };
        event diag => { message => 'xxx', stash => sub {check_stash(@_, 1)} };
        event note => { message => 'yyy', stash => sub {check_stash(@_, 2)} };
    },
    "Got expected events"
);

sub check_stash {
    my ($key, $stash, $num) = @_;
    return $stash->{foo} eq "Num: $num";
}

done_testing;
