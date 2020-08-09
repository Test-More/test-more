package Test2::API::InterceptResult::Event;
use strict;
use warnings;

use List::Util qw/first/;
use Scalar::Util qw/reftype/;
use Carp qw/confess/;

use Test2::Util::HashBase qw{
    <facet_data
};

my %FACETS;
BEGIN {
    local *plugins;
    require Module::Pluggable;
    Module::Pluggable->import(
        # We will replace the sub later
        require => 1,
        on_require_error => sub { 1 },
        search_path =>  ['Test2::EventFacet'],
        max_depth => 3,
        min_depth => 3,
    );

    for my $facet_type (__PACKAGE__->plugins) {
        local $@;
        my ($key, $list);
        eval {
            $key = $facet_type->facet_key;
            $list = $facet_type->is_list;
        };
        next unless $key && defined($list);

        $FACETS{$key} = {list => $list, class => $facet_type};
    }
}

sub facet_map { \%FACETS }

sub init {
    my $self = shift;

    my $fd = $self->{+FACET_DATA} ||= {};

    for my $facet (keys %$fd) {
        next unless $FACETS{$facet};
        my $type = reftype($fd->{$facet});

        my $is_list = $FACETS{$facet}->{list};
        if ($is_list) {
            confess "Facet '$facet' is a list facet, but got '$type' instead of an arrayref"
                unless $type eq 'ARRAY';

            for my $item (@{$fd->{$facet}}) {
                my $itype = reftype($item);
                next if $itype eq 'HASH';

                confess "Got item type '$itype' in list-facet '$facet', all items must be hashrefs";
            }
        }
        else {
            confess "Facet '$facet' is an only-one facet, but got '$type' instead of a hashref"
                unless $type eq 'HASH';
        }
    }
}

sub facet {
    my $self = shift;
    my ($name) = @_;

    return () unless exists $self->{+FACET_DATA}->{$name};

    my $data = $self->{+FACET_DATA}->{$name};

    my $type = reftype($data) or confess "Facet '$name' has a value that is not a reference, this should not happen";
    return ($data)  if $type eq 'HASH';
    return (@$data) if $type eq 'ARRAY';

    confess "Facet '$name' has a value that is not an arrayref or hashref: '$type', this should not happen";
}

{
    require Test2::Hub;
    my $file = $INC{'Test2/Hub.pm'} or die "Could not find file for Test2::Hub";
    open(my $fh, '<', $file) or die "Could not open '$file': $!";
    my $found;
    my $code = "";
    my $ln = 0;
    while (my $line = <$fh>) {
        $ln++;

        $found ||= $ln if $line =~ m/# FAIL_CHECK_START/;
        next unless $found;

        last if $line =~ m/# FAIL_CHECK_END/;

        $code .= $line;
    }

    die "Could not find FAIL_CHECK_START marker in $file" unless $found;

    eval <<"    EOT" or die $@;
sub causes_failure {
    my \$e = shift;

package Test2::Hub;
#line $found $file
$code

package ${ \__PACKAGE__ };
#line ${ \__LINE__ } ${ \__FILE__ }
    return \$fail ? 1 : 0;
}

1;
    EOT
}

sub causes_fail { goto &causes_failure }

sub trace         { $_[0]->{+FACET_DATA}->{trace}                       || undef }
sub frame         { my $t = $_[0]->trace or return undef; $t->{frame}   || undef }
sub trace_details { my $t = $_[0]->trace or return undef; $t->{details} || undef }
sub trace_package { my $f = $_[0]->frame or return undef; $f->[0]       || undef }
sub trace_file    { my $f = $_[0]->frame or return undef; $f->[1]       || undef }
sub trace_line    { my $f = $_[0]->frame or return undef; $f->[2]       || undef }
sub trace_subname { my $f = $_[0]->frame or return undef; $f->[3]       || undef }

sub brief {
    my $self = shift;

    my @try = qw{
        bailout_brief
        error_brief
        assert_brief
        plan_brief
    };

    for my $meth (@try) {
        my $got = $self->$meth or next;
        return $got;
    }

    return;
}

sub summary {
    my $self = shift;

    return {
        brief => $self->brief || '',

        causes_failure => $self->causes_failure,

        trace_line    => $self->trace_line,
        trace_file    => $self->trace_file,
        trace_tool    => $self->trace_subname,
        trace_details => $self->trace_details,

        is_assert  => $self->is_assert,
        is_subtest => $self->is_subtest,
        is_plan    => $self->is_plan,
        is_bailout => $self->is_bailout,

        diag       => join("\n" => $self->diag_messages),
        note       => join("\n" => $self->note_messages),
        other_info => join("\n" => $self->other_info_messages),
    };
}

sub is_assert { $_[0]->{+FACET_DATA}->{assert} ? 1 : 0 }
sub assert    { $_[0]->facet('assert') }

sub assert_brief {
    my $self = shift;

    my $fd = $self->{+FACET_DATA};
    my $as = $fd->{assert} or return;
    my $am = $fd->{amnesty};

    my $out = $as->{pass} ? "PASS" : "FAIL";
    $out .= " with amnesty" if $am;
    return $out;
}

sub assert_summary {
    my $self = shift;

    my $as = $self->{+FACET_DATA}->{assert} or return;

    return {
        %{$self->summary},

        pass  => $as->{pass}     ? 1 : 0,
        debug => $as->{no_debug} ? 0 : 1,

        name => defined($as->{details}) ? $as->{details} : '',

        amnesty => $self->is_todo || $self->is_skip || $self->has_amnesty || 0,

        todo          => $self->is_todo     ? join("\n" => $self->todo_reasons)          || "[yes, but no reasons given]" : undef,
        skip          => $self->is_skip     ? join("\n" => $self->skip_reasons)          || "[yes, but no reasons given]" : undef,
        other_amnesty => $self->has_amnesty ? join("\n" => $self->other_amnesty_reasons) || "[yes, but no reasons given]" : undef,
    };
}

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
