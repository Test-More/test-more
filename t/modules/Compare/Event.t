use Test::Stream -V1, Class => ['Test::Stream::Compare::Event'];

my $one = $CLASS->new(etype => 'Ok');
is($one->name, '<EVENT: Ok>', "got name");
is($one->meta_class, 'Test::Stream::Compare::EventMeta', "correct meta class");
is($one->object_base, 'Test::Stream::Event', "Event is the base class");

my $dbg = Test::Stream::DebugInfo->new(frame => ['Foo', 'foo.t', 42, 'foo']);
my $Ok = Test::Stream::Event::Ok->new(debug => $dbg, pass => 1);

is($one->got_lines(), undef, "no lines");
is($one->got_lines('xxx'), undef, "no lines");
is($one->got_lines(bless {}, 'XXX'), undef, "no lines");
is($one->got_lines($Ok), 42, "got the correct line");

done_testing;
