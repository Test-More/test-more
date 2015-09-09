my (%BEFORE_INC, %AFTER_INC);
BEGIN { %BEFORE_INC = %INC };
use Test::Stream qw/-V1/;
BEGIN { %AFTER_INC = %INC };

use Test::Stream qw/Spec LoadPlugin/;

ok( Test::Stream::Sync->hooks, "hook added");

tests strictures => sub {
    local $^H;
    my $hbefore = $^H;
    load_plugin('-V1');
    my $hafter = $^H;

    my $strict = do { local $^H; strict->import(); $^H };

    ok($strict,               'sanity, got $^H value for strict');
    ok(!($hbefore & $strict), "strict is not on before loading Test::Stream");
    ok(($hafter & $strict),   "strict is on after loading Test::Stream");
};

tests warnings => sub {
    local ${^WARNING_BITS};
    my $wbefore = ${^WARNING_BITS} || '';
    load_plugin('-V1');
    my $wafter = ${^WARNING_BITS} || '';

    my $warnings = do { local ${^WARNING_BITS}; warnings->import(); ${^WARNING_BITS} || '' };

    ok($warnings, 'sanity, got ${^WARNING_BITS} value for warnings');
    ok($wbefore ne $warnings, "warnings are not on before loading Test::Stream") || diag($wbefore, "\n", $warnings);
    ok(($wafter & $warnings), "warnings are on after loading Test::Stream");
};

tests loaded_plugins => sub {
    my @files = qw{
        Test/Stream/Plugin/IPC.pm
        Test/Stream/Plugin/TAP.pm
        Test/Stream/Plugin/ExitSummary.pm
        Test/Stream/Plugin/Core.pm
        Test/Stream/Plugin/Context.pm
        Test/Stream/Plugin/Subtest.pm
        Test/Stream/Plugin/Exception.pm
        Test/Stream/Plugin/Warnings.pm
        Test/Stream/Plugin/Compare.pm
        Test/Stream/Plugin/Mock.pm
    };

    ok(!$BEFORE_INC{$_}, "$_ is not preloaded") for @files;
    ok($AFTER_INC{$_},   "$_ is loaded") for @files;

    imported_ok qw{
        BAIL_OUT
        DOES_ok
        can_ok
        context
        diag
        dies
        done_testing
        fail
        imported_ok
        is
        isa_ok
        like
        lives
        mock
        mocked
        no_warnings
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
        todo
        warning
        warns
    };
};

done_testing;
