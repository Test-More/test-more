package Test2::API::InterceptResult::Event;
use strict;
use warnings;

our $VERSION = '1.302178';

use List::Util   qw/first uniq/;
use Test2::Util  qw/pkg_to_file/;
use Scalar::Util qw/reftype blessed/;

use Storable qw/dclone/;
use Carp     qw/confess croak/;

use Test2::API::InterceptResult::Facet;
use Test2::API::InterceptResult::Hub;

use Test2::Util::HashBase qw{
    +causes_failure
    <facet_data
    <result_class
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

        $FACETS{$key} = {list => $list, class => $facet_type, loaded => 1};
    }

    $FACETS{__GENERIC__} = {class => 'Test2::API::InterceptResult::Facet', loaded => 1};
}

sub facet_map { \%FACETS }

sub init {
    my $self = shift;

    my $rc = $self->{+RESULT_CLASS} ||= 'Test2::API::InterceptResult';
    my $rc_file = pkg_to_file($rc);
    require($rc_file) unless $INC{$rc_file};

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

sub clone {
    my $self = shift;
    my $class = blessed($self);

    my %data = %$self;

    $data{+FACET_DATA} = dclone($data{+FACET_DATA});

    return bless(\%data, $class);
}

sub _facet_class {
    my $self = shift;
    my ($name) = @_;

    my $spec  = $FACETS{$name} || $FACETS{__GENERIC__};
    my $class = $spec->{class};
    unless ($spec->{loaded}) {
        my $file = pkg_to_file($class);
        require $file unless $INC{$file};
        $spec->{loaded} = 1;
    }

    return $class;
}

sub the_facet {
    my $self = shift;
    my ($name) = @_;

    return undef unless exists $self->{+FACET_DATA}->{$name};

    my $data = $self->{+FACET_DATA}->{$name};

    my $type = reftype($data) or confess "Facet '$name' has a value that is not a reference, this should not happen";

    return $self->_facet_class($name)->new(%{dclone($data)})
        if $type eq 'HASH';

    if ($type eq 'ARRAY') {
        return undef unless @$data;
        croak "'the_facet' called for facet '$name', but '$name' has '" . @$data . "' items" if @$data != 1;
        return $self->_facet_class($name)->new(%{dclone($data->[0])});
    }

    die "Invalid facet data type: $type";
}

sub facet {
    my $self = shift;
    my ($name) = @_;

    return () unless exists $self->{+FACET_DATA}->{$name};

    my $data = $self->{+FACET_DATA}->{$name};

    my $type = reftype($data) or confess "Facet '$name' has a value that is not a reference, this should not happen";

    my @out;
    @out = ($data)  if $type eq 'HASH';
    @out = (@$data) if $type eq 'ARRAY';

    my $class = $self->_facet_class($name);

    return map { $class->new(%{dclone($_)}) } @out;
}

sub causes_failure {
    my $self = shift;

    return $self->{+CAUSES_FAILURE}
        if exists $self->{+CAUSES_FAILURE};

    my $hub = Test2::API::InterceptResult::Hub->new();
    $hub->process($self);

    return $self->{+CAUSES_FAILURE} = ($hub->is_passing ? 0 : 1);
}

sub causes_fail { shift->causes_failure }

sub trace         { $_[0]->facet('trace') }
sub the_trace     { $_[0]->the_facet('trace') }
sub frame         { my $t = $_[0]->the_trace or return undef; $t->{frame} || undef }
sub trace_details { my $t = $_[0]->the_trace or return undef; $t->{details} || undef }
sub trace_package { my $f = $_[0]->frame or return undef; $f->[0] || undef }
sub trace_file    { my $f = $_[0]->frame or return undef; $f->[1] || undef }
sub trace_line    { my $f = $_[0]->frame or return undef; $f->[2] || undef }
sub trace_subname { my $f = $_[0]->frame or return undef; $f->[3] || undef }
sub trace_tool    { my $f = $_[0]->frame or return undef; $f->[3] || undef }

sub trace_signature { my $t = $_[0]->the_trace or return undef; Test2::EventFacet::Trace::signature($t) || undef }

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

sub flatten {
    my $self = shift;
    my %params = @_;

    my $todo = {%{$self->{+FACET_DATA}}};
    delete $todo->{hubs};
    delete $todo->{meta};
    delete $todo->{trace};

    my $out = $self->summary;
    delete $out->{brief};
    delete $out->{facets};
    delete $out->{trace_tool};
    delete $out->{trace_details} unless defined($out->{trace_details});

    for my $tagged (grep { $FACETS{$_}->{list} && $FACETS{$_}->{class}->can('tag') } keys %FACETS) {
        my $set = delete $todo->{$tagged} or next;

        my $fd = $self->{+FACET_DATA};
        my $has_assert = $self->has_assert;
        my $has_parent = $self->has_subtest;
        my $has_fatal_error = $self->has_errors && grep { $_->{fail} } $self->errors;

        next if $tagged eq 'amnesty' && !($has_assert || $has_parent || $has_fatal_error);

        for my $item (@$set) {
            push @{$out->{lc($item->{tag})}} => $item->{fail} ? "FATAL: $item->{details}" : $item->{details};
        }
    }

    if (my $assert = delete $todo->{assert}) {
        $out->{pass} = $assert->{pass};
        $out->{name} = $assert->{details};
    }

    if (my $parent = delete $todo->{parent}) {
        delete $out->{subtest}->{bailed_out}  unless defined $out->{subtest}->{bailed_out};
        delete $out->{subtest}->{skip_reason} unless defined $out->{subtest}->{skip_reason};

        if (my $res = $self->subtest_result) {
            my $state = $res->state;
            delete $state->{$_} for grep { !defined($state->{$_}) } keys %$state;
            $out->{subtest} = $state;
            $out->{subevents} = $res->flatten(%params)
                if $params{include_subevents};
        }
    }

    if (my $control = delete $todo->{control}) {
        if ($control->{halt}) {
            $out->{bailed_out} = $control->{details} || 1;
        }
        elsif(defined $control->{details}) {
            $out->{control} = $control->{details};
        }
    }

    if (my $plan = delete $todo->{plan}) {
        $out->{plan} = $self->plan_brief;
        $out->{plan} =~ s/^PLAN\s*//;
    }

    for my $other (keys %$todo) {
        my $data = $todo->{$other} or next;

        if (reftype($data) eq 'ARRAY') {
            if (!$out->{$other} || reftype($out->{$other}) eq 'ARRAY') {
                for my $item (@$data) {
                    push @{$out->{$other}} => $item->{details} if defined $item->{details};
                }
            }
        }
        else {
            $out->{$other} = $data->{details} if defined($data->{details}) && !defined($out->{$other});
        }
    }

    if (my $fields = $params{fields}) {
        $out = { map {exists($out->{$_}) ? ($_ => $out->{$_}) : ()} @$fields };
    }

    if (my $remove = $params{remove}) {
        delete $out->{$_} for @$remove;
    }

    return $out;
}

sub summary {
    my $self = shift;
    my %params = @_;

    my $out = {
        brief => $self->brief || '',

        causes_failure => $self->causes_failure,

        trace_line    => $self->trace_line,
        trace_file    => $self->trace_file,
        trace_tool    => $self->trace_subname,
        trace_details => $self->trace_details,

        facets => [ sort keys(%{$self->{+FACET_DATA}}) ],
    };

    if (my $fields = $params{fields}) {
        $out = { map {exists($out->{$_}) ? ($_ => $out->{$_}) : ()} @$fields };
    }

    if (my $remove = $params{remove}) {
        delete $out->{$_} for @$remove;
    }

    return $out;
}

sub has_assert { $_[0]->{+FACET_DATA}->{assert} ? 1 : 0 }
sub the_assert { $_[0]->the_facet('assert') }
sub assert     { $_[0]->facet('assert') }

sub assert_brief {
    my $self = shift;

    my $fd = $self->{+FACET_DATA};
    my $as = $fd->{assert} or return;
    my $am = $fd->{amnesty};

    my $out = $as->{pass} ? "PASS" : "FAIL";
    $out .= " with amnesty" if $am;
    return $out;
}

sub has_subtest { $_[0]->{+FACET_DATA}->{parent} ? 1 : 0 }
sub the_subtest { $_[0]->the_facet('parent') }
sub subtest     { $_[0]->facet('parent') }

sub subtest_result {
    my $self = shift;

    my $parent = $self->{+FACET_DATA}->{parent} or return;
    my $children = $parent->{children} || [];

    $children = $self->{+RESULT_CLASS}->new(@$children)->upgrade
        unless blessed($children) && $children->isa($self->{+RESULT_CLASS});

    return $children;
}

sub has_bailout { $_[0]->bailout ? 1 : 0 }
sub the_bailout { my ($b) = $_[0]->bailout; $b }

sub bailout {
    my $self = shift;
    my $control = $self->{+FACET_DATA}->{control} or return;
    return $control if $control->{halt};
    return;
}

sub bailout_brief {
    my $self = shift;
    my $bo = $self->bailout or return;

    my $reason = $bo->{details} or return "BAILED OUT";
    return "BAILED OUT: $reason";
}

sub bailout_reason {
    my $self = shift;
    my $bo = $self->bailout or return;
    return $bo->{details} || '';
}

sub has_plan { $_[0]->{+FACET_DATA}->{plan} ? 1 : 0 }
sub the_plan { $_[0]->the_facet('plan') }
sub plan     { $_[0]->facet('plan') }

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
sub the_amnesty     { $_[0]->the_facet('amnesty') }
sub amnesty         { $_[0]->facet('amnesty') }
sub amnesty_reasons { map { $_->{details} } $_[0]->amnesty }

sub has_todos    { &first(sub { uc($_->{tag}) eq 'TODO' }, $_[0]->amnesty) ? 1 : 0 }
sub todos        {       grep { uc($_->{tag}) eq 'TODO' }  $_[0]->amnesty          }
sub todo_reasons {       map  { $_->{details} || 'TODO' }  $_[0]->todos            }

sub has_skips    { &first(sub { uc($_->{tag}) eq 'SKIP' }, $_[0]->amnesty) ? 1 : 0 }
sub skips        {       grep { uc($_->{tag}) eq 'SKIP' }  $_[0]->amnesty          }
sub skip_reasons {       map  { $_->{details} || 'SKIP' }  $_[0]->skips            }

my %TODO_OR_SKIP = (SKIP => 1, TODO => 1);
sub has_other_amnesty     { &first( sub { !$TODO_OR_SKIP{uc($_->{tag})}            }, $_[0]->amnesty) ? 1 : 0 }
sub other_amnesty         {        grep { !$TODO_OR_SKIP{uc($_->{tag})}            }  $_[0]->amnesty          }
sub other_amnesty_reasons {        map  { $_->{details} ||  $_->{tag} || 'AMNESTY' }  $_[0]->other_amnesty    }

sub has_errors     { $_[0]->{+FACET_DATA}->{errors} ? 1 : 0 }
sub the_errors     { $_[0]->the_facet('errors') }
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
sub the_info      { $_[0]->the_facet('info') }
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
