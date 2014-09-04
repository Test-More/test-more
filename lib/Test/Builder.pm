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
use Test::Stream::Util qw/try protect unoverload_str/;
use Scalar::Util qw/blessed/;

BEGIN {
    Test::Stream->shared->set_use_legacy([]);
}

# The mostly-singleton, and other package vars.
our $Test  = Test::Builder->new;
our $Level = 1;

sub ctx { Test::Provider::context($Level + 1) }

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

#############################
# {{{ Children and subtests #
#############################

sub child {
    my( $self, $name, $is_subtest ) = @_;

    $self->croak("You already have a child named ($self->{Child_Name}) running")
        if $self->{Child_Name};

    my $parent_in_todo = $self->in_todo;

    # Clear $TODO for the child.
    my $orig_TODO = $self->find_TODO(undef, 1, undef);

    my $class = blessed($self);
    my $child = $class->create;

    $child->{stream} = $self->stream->spawn;

    # Ensure the child understands if they're inside a TODO
    $child->tap->failure_output($self->tap->todo_output)
        if $parent_in_todo && $self->tap;

    # This will be reset in finalize. We do this here lest one child failure
    # cause all children to fail.
    $child->{Child_Error} = $?;
    $?                    = 0;

    $child->{Parent}      = $self;
    $child->{Parent_TODO} = $orig_TODO;
    $child->{Name}        = $name || "Child of " . $self->name;

    $self->{Child_Name}   = $child->name;

    $child->depth($self->depth + 1);

    my $res = Test::Builder::Event::Child->new(
        $self->context,
        name    => $child->name,
        action  => 'push',
        in_todo => $self->in_todo || 0,
        is_subtest => $is_subtest || 0,
    );
    $self->stream->send($res);

    return $child;
}

sub subtest {
    my $self = shift;
    my($name, $subtests, @args) = @_;

    $self->croak("subtest()'s second argument must be a code ref")
        unless $subtests && 'CODE' eq Scalar::Util::reftype($subtests);

    # Turn the child into the parent so anyone who has stored a copy of
    # the Test::Builder singleton will get the child.
    my ($success, $error, $child);
    my $parent = {};
    {
        local $Level = 1;
        # Store the guts of $self as $parent and turn $child into $self.
        $child  = $self->child($name, 1);

        _copy($self,  $parent);
        _copy($child, $self);

        my $run_the_subtests = sub {
            $subtests->(@args);
            $self->done_testing unless defined $self->stream->plan;
            1;
        };

        ($success, $error) = try { Test::Builder::Trace->nest($run_the_subtests) };
    }

    # Restore the parent and the copied child.
    _copy($self,   $child);
    _copy($parent, $self);

    # Restore the parent's $TODO
    $self->find_TODO(undef, 1, $child->{Parent_TODO});

    # Die *after* we restore the parent.
    die $error if $error && !(blessed($error) && $error->isa('Test::Builder::Exception'));

    my $finalize = $child->finalize(1);

    $self->BAIL_OUT($child->{Bailed_Out_Reason}) if $child->_bailed_out;

    return $finalize;
}

sub finalize {
    my $self = shift;
    my ($is_subtest) = @_;

    return unless $self->parent;
    if( $self->{Child_Name} ) {
        $self->croak("Can't call finalize() with child ($self->{Child_Name}) active");
    }

    local $? = 0;     # don't fail if $subtests happened to set $? nonzero
    $self->_ending;

    my $ok = 1;
    $self->parent->{Child_Name} = undef;

    unless ($self->_bailed_out) {
        if ( $self->{Skip_All} ) {
            $self->parent->skip($self->{Skip_All});
        }
        elsif ( ! $self->stream->tests_run ) {
            $self->parent->ok( 0, sprintf q[No tests run for subtest "%s"], $self->name );
        }
        else {
            $self->parent->ok( $self->is_passing, $self->name );
        }
    }

    $? = $self->{Child_Error};
    my $parent = delete $self->{Parent};

    my $res = Test::Builder::Event::Child->new(
        $self->context,
        name    => $self->{Name} || undef,
        action  => 'pop',
        in_todo => $self->in_todo || 0,
        is_subtest => $is_subtest || 0,
    );
    $parent->stream->send($res);

    return $self->is_passing;
}

#############################
# }}} Children and subtests #
#############################

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

#############################
# {{{ Base Event Producers #
#############################

sub ok {
    my $self = shift;
    my($test, $name) = @_;
    ctx()->ok($test, $name);
    return $test ? 1 : 0;
}

sub BAIL_OUT {
    my( $self, $reason ) = @_;

    $self->_bailed_out(1);

    if ($self->parent) {
        $self->{Bailed_Out_Reason} = $reason;
        $self->no_ending(1);
        die bless {} => 'Test::Builder::Exception';
    }

    ctx()->bail($reason);
}

sub skip {
    my( $self, $why ) = @_;
    $why ||= '';
    unoverload_str( \$why );

    my $ctx = ctx();
    $ctx->set_skip($why);
    $ctx->ok(1);
    $ctx->set_skip(undef);
}

sub todo_skip {
    my( $self, $why ) = @_;
    $why ||= '';
    unoverload_str( \$why );

    my $ctx = ctx();
    $ctx->set_skip($why);
    $ctx->set_todo($why);
    $ctx->ok(1);
    $ctx->set_skip(undef);
    $ctx->set_todo(undef);
}

sub diag {
    my $self = shift;
    my $msg = join '', map { defined($_) ? $_ : 'undef' } @_;
    ctx->diag($msg);
}

sub note {
    my $self = shift;
    my $msg = join '', map { defined($_) ? $_ : 'undef' } @_;
    ctx->note($msg);
}

#############################
# }}} Base Event Producers #
#############################

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
