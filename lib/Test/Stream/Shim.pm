package Test::Stream::Shim;
use strict;
use warnings;

use Test::Stream::Carp qw/confess/;

my %REDIRECT = (
    'Test/Builder/Module.pm'       => 1,
    'Test/Builder/Tester/Color.pm' => 1,
    'Test/Builder/Tester.pm'       => 1,
    'Test/Builder.pm'              => 1,
    'Test/More.pm'                 => 1,
    'Test/Simple.pm'               => 1,
    'Test/Tester/CaptureRunner.pm' => 1,
    'Test/Tester/Capture.pm'       => 1,
    'Test/Tester/Delegate.pm'      => 1,
    'Test/Tester.pm'               => 1,
    'Test/use/ok.pm'               => 1,
    'ok.pm'                        => 1,
);

for my $file (sort keys %REDIRECT) {
    next unless $INC{$file};
    confess "$file has already been loaded, Test::Stream must be loaded first";
}

unshift @INC => sub {
    my ($us, $file) = @_;
    return unless $REDIRECT{$file};

    my $rewrite = $file;
    $rewrite =~ s/\.pm$/_stream.pm/;
    require $rewrite;

    $INC{$file} = $INC{$rewrite};

    open(my $fh, '<', \"1");
    return $fh;
};

1;
