use strict;
use warnings;

use Test2::Tools::Tiny;
use Test2::API::InterceptResult::Event;

my $CLASS = 'Test2::API::InterceptResult::Event';

tests facet_map => sub {
    ok(!$CLASS->can('plugins'), "Did not expose 'plugins' sub");

    my $fm = $CLASS->facet_map;

    is_deeply($fm->{about},   {class => 'Test2::EventFacet::About',   list => 0}, "Found 'about' facet");
    is_deeply($fm->{amnesty}, {class => 'Test2::EventFacet::Amnesty', list => 1}, "Found 'amnesty' facet");
    is_deeply($fm->{assert},  {class => 'Test2::EventFacet::Assert',  list => 0}, "Found 'assert' facet");
    is_deeply($fm->{control}, {class => 'Test2::EventFacet::Control', list => 0}, "Found 'control' facet");
    is_deeply($fm->{errors},  {class => 'Test2::EventFacet::Error',   list => 1}, "Found 'errors' facet");
    is_deeply($fm->{hubs},    {class => 'Test2::EventFacet::Hub',     list => 1}, "Found 'hubs' facet");
    is_deeply($fm->{info},    {class => 'Test2::EventFacet::Info',    list => 1}, "Found 'info' facet");
    is_deeply($fm->{meta},    {class => 'Test2::EventFacet::Meta',    list => 0}, "Found 'meta' facet");
    is_deeply($fm->{parent},  {class => 'Test2::EventFacet::Parent',  list => 0}, "Found 'parent' facet");
    is_deeply($fm->{plan},    {class => 'Test2::EventFacet::Plan',    list => 0}, "Found 'plan' facet");
    is_deeply($fm->{render},  {class => 'Test2::EventFacet::Render',  list => 1}, "Found 'render' facet");
    is_deeply($fm->{trace},   {class => 'Test2::EventFacet::Trace',   list => 0}, "Found 'trace' facet");
};

tests init => sub {
    my $one = $CLASS->new();
    ok($one->isa($CLASS), "Got an instance");
    is_deeply($one->facet_data, {}, "Got empty data");

    like(
        exception { $CLASS->new(facet_data => {assert => [{}]}) },
        qr/^Facet 'assert' is an only-one facet, but got 'ARRAY' instead of a hashref/,
        "Check list vs non-list when we can (check for single)"
    );

    like(
        exception { $CLASS->new(facet_data => {info => {}}) },
        qr/^Facet 'info' is a list facet, but got 'HASH' instead of an arrayref/,
        "Check list vs non-list when we can (check for list)"
    );

    like(
        exception { $CLASS->new(facet_data => {info => [{},[]]}) },
        qr/Got item type 'ARRAY' in list-facet 'info', all items must be hashrefs/,
        "Check each item in a list facet is a hashref"
    );

    my $two = $CLASS->new(facet_data => {assert => {}, info => [{}]});
    ok($two->isa($CLASS), "Got an instance with some actual facets");
};

tests facet => sub {
    my $one = $CLASS->new(facet_data => {
        assert => {pass => 1, details => 'xxx'},
        info => [
            {tag => 'DIAG', details => 'xxx'},
            {tag => 'NOTE', details => 'xxx'},
        ],
    });

    is_deeply(
        [$one->facet('xxx')],
        [],
        "Got an empty list when facet is not present",
    );

    is_deeply(
        [$one->facet('assert')],
        [{pass => 1, details => 'xxx'}],
        "One item list for non-list facets",
    );

    is_deeply(
        [$one->facet('info')],
        [
            {tag => 'DIAG', details => 'xxx'},
            {tag => 'NOTE', details => 'xxx'},
        ],
        "Full list for list facets"
    );
};

tests causes_failure => sub {
    my $one = $CLASS->new(facet_data => { assert => {pass => 1, details => 'xxx'}});
    ok(!$one->causes_fail, "No failure for passing test");
    ok(!$one->causes_failure, "No failure for passing test (alt name)");

    $one->{facet_data}->{assert}->{pass} = 0;
    ok($one->causes_fail, "Failure for failing test");
    ok($one->causes_failure, "Failure for failing test (alt name)");

    # We rip the logic out of the hub sourcecode, so make sure that souce is
    # what gets reported
    $one->{facet_data}->{assert} = 'xxx';
    like(
        exception { $one->causes_fail },
        qr/Can't use string .* as a HASH ref while "strict refs" in use at .*Hub\.pm line \d+/,
        "Exception in the logic points at the hub"
    );
};

tests trace => sub {
    my $one = $CLASS->new;
    is($one->trace,         undef, "No trace to get");
    is($one->frame,         undef, "No frame to get");
    is($one->trace_details, undef, "No trace to get trace_details from");
    is($one->trace_file,    undef, "No trace to get trace_file from");
    is($one->trace_line,    undef, "No trace to get trace_line from");
    is($one->trace_package, undef, "No trace to get trace_package from");
    is($one->trace_subname, undef, "No trace to get trace_subname from");

    my $two = $CLASS->new(
        facet_data => {
            trace => {
                details => 'xxx',
            },
        }
    );
    is_deeply($two->trace, {details => 'xxx'}, "Got trace");
    is($two->trace_details, 'xxx', "get trace_details");
    is($two->frame,         undef, "No frame to get");
    is($two->trace_file,    undef, "No frame to get trace_file from");
    is($two->trace_line,    undef, "No frame to get trace_line from");
    is($two->trace_package, undef, "No frame to get trace_package from");
    is($two->trace_subname, undef, "No frame to get trace_subname from");

    my $three = $CLASS->new(
        facet_data => {
            trace => {
                details => 'xxx',
                frame   => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok'],
            },
        }
    );
    is_deeply($three->trace, {details => 'xxx', frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok']}, "Got trace");
    is($three->trace_details, 'xxx', "get trace_details");
    is_deeply($three->frame, ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok'], "Got frame");
    is($three->trace_file,    'Foo/Bar.pm', "Got trace_file");
    is($three->trace_line,    42,           "Got trace_line");
    is($three->trace_package, 'Foo::Bar',   "Got trace_package");
    is($three->trace_subname, 'ok',         "Got trace_subname");
};

tests brief => sub {
    my $one = $CLASS->new(
        facet_data => {
            control => {halt => 1, details => "some reason to bail out"},
            errors  => [{tag => 'ERROR', details => "some kind of error"}],
            assert  => {pass => 1, details => "some passing assert"},
            plan    => {count => 42},
        }
    );

    is($one->brief, $one->bailout_brief, "bail-out is used when present");
    delete $one->{facet_data}->{control};

    is($one->brief, $one->error_brief, "error is next");
    delete $one->{facet_data}->{errors};

    is($one->brief, $one->assert_brief, "assert is next");
    delete $one->{facet_data}->{assert};

    is($one->brief, $one->plan_brief, "plan is last");
    delete $one->{facet_data}->{plan};

    is_deeply(
        [$one->brief],
        [],
        "Empty list if no briefs are available."
    );
};

tests summary => sub {
    my $one = $CLASS->new();

    is_deeply(
        $one->summary,
        {
            brief => '',

            causes_failure => 0,

            trace_line    => undef,
            trace_file    => undef,
            trace_tool    => undef,
            trace_details => undef,

            is_assert  => 0,
            is_subtest => 0,
            is_plan    => 0,
            is_bailout => 0,

            diag       => '',
            note       => '',
            other_info => '',
        },
        "Got summary for empty event"
    );

    my $two = $CLASS->new(facet_data => {
        assert => {pass => 0},
        trace => {frame => ['Foo::Bar', 'Foo/Bar.pm', 42, 'ok'], details => 'a trace'},
        parent => {},
        plan => {},
        control => {halt => 1, details => "bailout wins"},
        info => [
            {tag => 'DIAG', details => 'diag 1'},
            {tag => 'DIAG', details => 'diag 2'},
            {tag => 'NOTE', details => 'note 1'},
            {tag => 'NOTE', details => 'note 2'},
            {tag => 'OTHER', details => 'other 1'},
            {tag => 'OTHER', details => 'other 2'},
        ],
    });

    is_deeply(
        $two->summary,
        {
            brief => 'BAILED OUT: bailout wins',

            causes_failure => 1,

            trace_line    => 42,
            trace_file    => 'Foo/Bar.pm',
            trace_tool    => 'ok',
            trace_details => 'a trace',

            is_assert  => 1,
            is_subtest => 1,
            is_plan    => 1,
            is_bailout => 1,

            diag       => "diag 1\ndiag 2",
            note       => "note 1\nnote 2",
            other_info => "other 1\nother 2",
        },
        "Got summary for everything"
    );
};

tests assert => sub {
    my $one = $CLASS->new();
    ok(!$one->is_assert, "Not an assert");
    is_deeply([$one->assert],         [], "empty list for assert()");
    is_deeply([$one->assert_brief],   [], "empty list for assert_brief()");
    is_deeply([$one->assert_summary], [], "empty list for assert_summary()");

    my $two = $CLASS->new(facet_data => {assert => {pass => 1, details => 'foo'}});
    ok($two->is_assert, "Is an assert");
    is_deeply([$two->assert], [{pass => 1, details => 'foo'}], "got assert item");
    is($two->assert_brief, "PASS", "got PASS for assert_brief()");
    is_deeply(
        $two->assert_summary, {
            %{$two->summary},

            pass  => 1,
            debug => 1,
            name  => 'foo',

            amnesty       => 0,
            todo          => undef,
            skip          => undef,
            other_amnesty => undef,
        },
        "Got summary"
    );

    my $three = $CLASS->new(facet_data => {
        assert => {pass => 0, details => 'foo'},
        amnesty => [
            {tag => 'TODO', details => 'todo 1'},
            {tag => 'SKIP', details => 'skip 1'},
            {tag => 'OOPS', details => 'oops 1'},
            {tag => 'TODO', details => 'todo 2'},
            {tag => 'SKIP', details => 'skip 2'},
            {tag => 'OOPS', details => 'oops 2'},
        ],
    });
    ok($three->is_assert, "Is an assert");
    is_deeply([$three->assert], [{pass => 0, details => 'foo'}], "got assert item");
    is($three->assert_brief, "FAIL with amnesty", "Fail with amnesty");
    is_deeply(
        $three->assert_summary, {
            %{$three->summary},

            pass  => 0,
            debug => 1,
            name  => 'foo',

            amnesty       => 1,
            todo          => "todo 1\ntodo 2",
            skip          => "skip 1\nskip 2",
            other_amnesty => "oops 1\noops 2",
        },
        "Got summary"
    );

    my $four = $CLASS->new(facet_data => {
        assert => {pass => 0, details => 'foo'},
        amnesty => [
            {tag => 'TODO'},
            {tag => 'SKIP'},
            {tag => 'OOPS'},
        ],
    });
    ok($four->is_assert, "Is an assert");
    is_deeply([$four->assert], [{pass => 0, details => 'foo'}], "got assert item");
    is($four->assert_brief, "FAIL with amnesty", "Fail with amnesty");
    is_deeply(
        $four->assert_summary, {
            %{$four->summary},

            pass  => 0,
            debug => 1,
            name  => 'foo',

            amnesty       => 1,
            todo          => "TODO",
            skip          => "SKIP",
            other_amnesty => "OOPS",
        },
        "Got summary"
    );
};

done_testing;

__END__

sub is_subtest { $_[0]->{+FACET_DATA}->{parent} ? 1 : 0 }
sub subtest    { $_[0]->facet('parent') }

sub subtest_summary {
    my $self = shift;

    my $pt = $self->{+FACET_DATA}->{parent} or return;

    return {
        %{ $self->assert_summary || $self->summary },
        %{$pt->{state}},
    };
}

sub subtest_result {
    my $self = shift;

    my $subtest = $_[0]->{+FACET_DATA}->{parent} or return;

    require Test2::API::InterceptResult;
    return Test2::API::InterceptResult->new(subtest_event => $self);
}

sub is_bailout { $_[0]->bail_out ? 1 : 0 }

sub bail_out {
    my $self = shift;
    my $control = $self->{+FACET_DATA}->{control} or return;
    return $control if $control->{halt};
    return;
}

sub bailout_brief {
    my $self = shift;
    my $bo = $self->bail_out or return;

    my $reason = $bo->{details} or return "BAILED OUT";
    return "BAILED OUT: $reason";
}

sub bail_out_reason {
    my $self = shift;
    my $bo = $self->bail_out or return undef;
    return $bo->{details} || '';
}

sub is_plan { $_[0]->{+FACET_DATA}->{plan} ? 1 : 0 }
sub plan { $_[0]->facet('plan') }

sub plan_brief {
    my $self = shift;

    my $plan = $self->{+FACET_DATA}->{plan} or return;

    my $base = $self->_plan_brief($plan);

    my $reason = $plan->{details} or return $base;
    return "$base: $reason";
}

sub _plan_brief {
    my $self = shift;
    my ($plan) = @_;

    return 'NO PLAN' if $plan->{none};
    return "SKIP ALL" if $plan->{skip} || !$plan->{count};
    return "PLAN $plan->{count}";
}

sub has_amnesty     { $_[0]->{+FACET_DATA}->{amnesty} ? 1 : 0 }
sub amnesties       { $_[0]->facet('amnesty') }
sub amnesty_reasons { map { $_->{details} } $_[0]->amnesties }

sub has_todos    { goto &is_todo }
sub is_todo      { &first(sub { uc($_->{tag}) eq 'TODO' }, $_[0]->amnesties) ? 1 : 0 }
sub todos        {       grep { uc($_->{tag}) eq 'TODO' }  $_[0]->amnesties          }
sub todo_reasons {       map  { $_->{details} || 'TODO' }  $_[0]->todos              }

sub has_skips    { goto &is_skip }
sub is_skip      { &first(sub { uc($_->{tag}) eq 'SKIP' }, $_[0]->amnesties) ? 1 : 0 }
sub skips        {       grep { uc($_->{tag}) eq 'SKIP' }  $_[0]->amnesties          }
sub skip_reasons {       map  { $_->{details} || 'SKIP' }  $_[0]->skips              }

my %TODO_OR_SKIP = (SKIP => 1, TODO => 1);
sub has_other_amnesties   { &first( sub { !$TODO_OR_SKIP{uc($_->{tag})}            }, $_[0]->amnesties) ? 1 : 0 }
sub other_amnesties       {        grep { !$TODO_OR_SKIP{uc($_->{tag})}            }  $_[0]->amnesties          }
sub other_amnesty_reasons {        map  { $_->{details} ||  $_->{tag} || 'AMNESTY' }  $_[0]->other_amnesties    }

sub has_errors     { $_[0]->{+FACET_DATA}->{errors} ? 1 : 0 }
sub errors         { $_[0]->facet('errors') }
sub error_messages { map { $_->{details} || $_->{tag} || 'ERROR' } $_[0]->errors }

sub error_brief {
    my $self = shift;

    my $errors = $self->{+FACET_DATA}->{errors} or return;

    my $base = @$errors > 1 ? "ERRORS" : "ERROR";

    return $base unless @$errors;

    my ($msg, @extra) = split /[\n\r]+/, $errors->[0]->{details};

    my $out = "$base: $msg";

    $out .= " [...]" if @extra || @$errors > 1;

    return $out;
}

sub has_info      { $_[0]->{+FACET_DATA}->{info} ? 1 : 0 }
sub info          { $_[0]->facet('info') }
sub info_messages { map { $_->{details} } $_[0]->info }

sub has_diags { &first(sub { uc($_->{tag}) eq 'DIAG' }, $_[0]->info) ? 1 : 0 }
sub diags         {   grep { uc($_->{tag}) eq 'DIAG' }  $_[0]->info          }
sub diag_messages {   map  { $_->{details} || 'DIAG' }  $_[0]->diags         }

sub has_notes { &first(sub { uc($_->{tag}) eq 'NOTE' }, $_[0]->info) ? 1 : 0 }
sub notes         {   grep { uc($_->{tag}) eq 'NOTE' }  $_[0]->info          }
sub note_messages {   map  { $_->{details} || 'NOTE' }  $_[0]->notes         }

my %NOTE_OR_DIAG = (NOTE => 1, DIAG => 1);
sub has_other_info { &first(sub { !$NOTE_OR_DIAG{uc($_->{tag})}         }, $_[0]->info) ? 1 : 0 }
sub other_info          {  grep { !$NOTE_OR_DIAG{uc($_->{tag})}         }  $_[0]->info          }
sub other_info_messages {  map  { $_->{details} ||  $_->{tag} || 'INFO' }  $_[0]->other_info    }

1;
