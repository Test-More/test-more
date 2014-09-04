package Test::Builder;

use 5.008001;
use strict;
use warnings;

our $VERSION = '1.301001_041';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use Test::Provider();
use Test::Provider::Context;
use Test::Stream;
use Test::Stream::Threads;
use Test::Stream::Util qw/try protect/;

BEGIN {
    *ctx = \&Test::Provider::context;
    Test::Stream->shared->set_use_legacy([]);
}

# The mostly-singleton, and other package vars.
our $Test  = Test::Builder->new;
our $Level = 1;

####################
# {{{ Constructors #
####################

sub new {
    my $class  = shift;
    my %params = @_;
    $Test ||= $class->create(shared_stream => 1);

    return $Test;
}

sub create {
    my $class  = shift;
    my %params = @_;

    my $self = bless {}, $class;
    $self->reset(%params);

    return $self;
}

# Copy an object, currently a shallow.
# This does *not* bless the destination.  This keeps the destructor from
# firing when we're just storing a copy of the object to restore later.
sub _copy {
    my ($src, $dest) = @_;
    %$dest = %$src;
    return;
}

####################
# }}} Constructors #
####################

#####################################
# {{{ stuff for TODO status #
#####################################

sub find_TODO {
    my ($self, $pack, $set, $new_value) = @_;

    if (my $ctx = Test::Provider::Context->peek) {
        $pack = $ctx->package;
        my $old = $ctx->todo;
        $ctx->set_todo($new_value) if $set;
        return $old;
    }

    $pack = $self->exported_to || return;

    no strict 'refs';    ## no critic
    no warnings 'once';
    my $old_value = ${$pack . '::TODO'};
    $set and ${$pack . '::TODO'} = $new_value;
    return $old_value;
}

sub todo {
    my ($self, $pack) = @_;

    return $self->{Todo} if defined $self->{Todo};

    my $todo = $self->find_TODO($pack);
    return $todo if defined $todo;

    return '';
}

sub in_todo {
    my $self = shift;

    return (defined $self->{Todo} || $self->find_TODO) ? 1 : 0;
}

sub todo_start {
    my $self = shift;
    my $message = @_ ? shift : '';

    $self->{Start_Todo}++;
    if ($self->in_todo) {
        push @{$self->{Todo_Stack}} => $self->todo;
    }
    $self->{Todo} = $message;

    return;
}

sub todo_end {
    my $self = shift;

    if (!$self->{Start_Todo}) {
        ctx()->throw('todo_end() called without todo_start()');
    }

    $self->{Start_Todo}--;

    if ($self->{Start_Todo} && @{$self->{Todo_Stack}}) {
        $self->{Todo} = pop @{$self->{Todo_Stack}};
    }
    else {
        delete $self->{Todo};
    }

    return;
}

#####################################
# }}} Finding Testers and Providers #
#####################################

################
# {{{ Planning #
################

my %PLAN_CMDS = (
    no_plan  => 'no_plan',
    skip_all => 'skip_all',
    tests    => '_plan_tests',
);

sub plan {
    my ($self, $cmd, $arg) = @_;
    return unless $cmd;

    if (my $method = $PLAN_CMDS{$cmd}) {
        $self->$method($arg);
    }
    else {
        my @args = grep { defined } ($cmd, $arg);
        ctx->throw("plan() doesn't understand @args");
    }

    return 1;
}

sub skip_all {
    my ($self, $reason) = @_;

    $self->{Skip_All} = $self->parent ? $reason : 1;

    die bless {} => 'Test::Builder::Exception' if $self->parent;
    ctx()->plan(0, 'SKIP', $reason);
}

sub no_plan {
    my ($self, @args) = @_;

    ctx()->alert("no_plan takes no arguments") if @args;
    ctx()->plan(0, 'NO_PLAN');

    return 1;
}

sub _plan_tests {
    my ($self, $arg) = @_;

    if ($arg) {
        ctx()->throw("Number of tests must be a positive integer.  You gave it '$arg'")
            unless $arg =~ /^\+?\d+$/;

        ctx()->plan($arg);
    }
    elsif (!defined $arg) {
        ctx()->throw("Got an undefined number of tests");
    }
    else {
        ctx()->throw("You said to run 0 tests");
    }

    return;
}

sub done_testing {
    my ($self, $num_tests) = @_;
    ctx()->done_testing($num_tests);
}

################
# }}} Planning #
################

####################
# {{{ TB1.5 stuff  #
####################

# This is just a list of method Test::Builder current does not have that Test::Builder 1.5 does.
my %TB15_METHODS = map { $_ => 1 } qw{
    _file_and_line _join_message _make_default _my_exit _reset_todo_state
    _result_to_hash _results _todo_state formatter history in_subtest in_test
    no_change_exit_code post_event post_result set_formatter set_plan test_end
    test_exit_code test_start test_state
};

our $AUTOLOAD;

sub AUTOLOAD {
    $AUTOLOAD =~ m/^(.*)::([^:]+)$/;
    my ($package, $sub) = ($1, $2);

    my @caller = CORE::caller();
    my $msg    = qq{Can't locate object method "$sub" via package "$package" at $caller[1] line $caller[2]\n};

    $msg .= <<"    EOT" if $TB15_METHODS{$sub};

    *************************************************************************
    '$sub' is a Test::Builder 1.5 method. Test::Builder 1.5 is a dead branch.
    You need to update your code so that it no longer treats Test::Builders
    over a specific version number as anything special.

    See: http://blogs.perl.org/users/chad_exodist_granum/2014/03/testmore---new-maintainer-also-stop-version-checking.html
    *************************************************************************
    EOT

    die $msg;
}

####################
# }}} TB1.5 stuff  #
####################

1;
