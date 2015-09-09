use Test::Stream -V1, LoadPlugin;

like(
    dies { load_plugin 'Class' },
    qr/No module specified for 'Class' plugin/,
    "Need an arg."
);

like(
    dies { load_plugin 'Class' => 'Ooops' },
    qr/No module specified for 'Class' plugin/,
    "Forgot to put the arg in an arrayref"
);

{
    local @INC = ('fake');
    my $file = __FILE__;
    my $line = __LINE__ + 2;
    like(
        dies { load_plugin Class => ['Fake'] },
        qr/Can't locate Fake\.pm in \@INC .* at \Q$file\E line \Q$line\E/,
        "Propogate error from module, use proper file and line number"
    );
}

ok(!__PACKAGE__->can('CLASS'), "no CLASS function yet");
ok(!$main::CLASS, "CLASS variable not set yet");

load_plugin Class => ['Test::Stream::Util'];
is(CLASS(), 'Test::Stream::Util', "Added 'CLASS' function");
is($main::CLASS, 'Test::Stream::Util', 'Set the $CLASS package variable');

done_testing;
