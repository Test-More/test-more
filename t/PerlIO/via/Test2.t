use strict;
use warnings;
use Test2::Tools::Tiny;
use Test2::API qw/intercept/;
use File::Temp qw/tempfile/;

use IO::Handle;
use PerlIO::via::Test2;

my ($wh, $filename) = tempfile();
$wh->autoflush(1);

local %PerlIO::via::Test2::PARAMS = (stream_name => 'stream a');
binmode($wh, 'via(PerlIO::via::Test2)') or die "Could not add Test2 perlio layer: $!";

my ($eval_result, $exception);
my @lines;
my $events = intercept {
    push @lines => __LINE__ + 1;
    print $wh "Foo\nBar\nBaz";
    push @lines => __LINE__ + 1;
    print $wh "bat\n";

    $eval_result = eval {
        no warnings 'redefine';
        local *Test2::API::Context::send_event = sub {die "XXX"};
        print $wh "Oops\n";
        1;
    };
    $exception = $@;

    my $stream = PerlIO::via::Test2->get_stream('stream a');
    local $stream->{no_event} = 1;
    print $wh "test\n";

    close($wh) or die "Could not close file";
};

ok($events->[0]->isa('Test2::Event::Output'), "Got first event");
is($events->[0]->message, "Foo\nBar\nBaz", "Got message, no added newline");
is($events->[0]->stream_name, 'stream a', "Stream name");
is($events->[0]->trace->file, __FILE__, "Report to correct file");
is($events->[0]->trace->line, $lines[0], "Report to correct line");

ok($events->[1]->isa('Test2::Event::Output'), "Got second event");
is($events->[1]->message, "bat\n", "Got message");
is($events->[1]->stream_name, 'stream a', "Stream name");
is($events->[1]->trace->file, __FILE__, "Report to correct file");
is($events->[1]->trace->line, $lines[1], "Report to correct line");

ok(!$eval_result, "Eval failed as expected");
like($exception, qr/XXX at /, "Got the expected exception");

open(my $rh, '<', $filename) or die "Could not open file '$filename': $!";
my $data = join '' => <$rh>;
close($rh);

is($data, <<EOT, "Got output, including data that could not be turned into an event due to exception");
Oops
test
EOT

unlink($filename);

done_testing;
