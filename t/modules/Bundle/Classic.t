my (%BEFORE_INC, %AFTER_INC);
BEGIN { %BEFORE_INC = %INC };
use Test::Stream qw/-Classic/;
BEGIN { %AFTER_INC = %INC };

ok(Test::Stream::Sync->hooks, "hook added");

my %files = (
    'Test/Stream/Plugin/IPC.pm'         => 1,
    'Test/Stream/Plugin/TAP.pm'         => 1,
    'Test/Stream/Plugin/ExitSummary.pm' => 1,
    'Test/Stream/Plugin/Core.pm'        => 1,
    'Test/Stream/Plugin/Classic.pm'     => 1,
    'Test/Stream/Plugin/Compare.pm'     => 1,
    'Test/Stream/Plugin/Subtest.pm'     => 1,
);

ok(!$BEFORE_INC{$_}, "$_ is not preloaded") for keys %files;
ok($AFTER_INC{$_},   "$_ is loaded")        for keys %files;

for my $file (keys %INC) {
    next unless $file =~ m{^Test/Stream/Plugin/};
    ok($files{$file}, "Plugin '$file' from %INC is on the 'OK' list");
}

imported_ok qw{
    BAIL_OUT
    DOES_ok
    can_ok
    diag
    done_testing
    fail
    imported_ok
    is
    isnt
    is_deeply
    isa_ok
    like
    unlike
    not_imported_ok
    note
    ok
    pass
    plan
    ref_is
    ref_is_not
    ref_ok
    set_encoding
    skip
    skip_all
    subtest
    todo
};

ref_is(\&is, \&Test::Stream::Plugin::Classic::is, "Correct 'is' function imported");
ref_is(\&is_deeply, \&Test::Stream::Plugin::Classic::is_deeply, "Correct 'is_deeply' function imported");

# Make sure we did not import other stuff from the Compare plugin
not_imported_ok qw{
    match mismatch validator
    hash array object meta number string
    in_set not_in_set check_set
    item field call prop check
    end filter_items
    T F D DNE FDNE
    event
    exact_ref
};

done_testing;
