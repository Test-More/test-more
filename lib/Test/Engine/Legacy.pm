package Test::Engine::Legacy;
use strict;
use warnings;

sub files {
    return {
        'Test::Builder' => 'Test/Builder/Legacy.pm',
        'Test::More'    => 'Test/More/Legacy.pm',
        'Test::Simple'  => 'Test/Simple/Legacy.pm',
        'Test::Tester'  => 'Test/Tester/Legacy.pm',

        'Test::Builder::Tester' => 'Test/Builder/Tester/Legacy.pm',
    };
}

1;
