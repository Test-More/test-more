package Test::Stream::Plugin::Mock;
use strict;
use warnings;

use Carp qw/croak/;
use Scalar::Util qw/blessed reftype weaken/;
use Test::Stream::Util qw/try/;
use Test::Stream::Workflow qw/workflow_build/;

use Test::Stream::Mock;
use Test::Stream::Workflow::Runner;
use Test::Stream::Workflow::Meta;

require Test::Stream::HashBase;

use Test::Stream::Exporter;
default_exports qw/mock mocked/;
exports qw{
    mock_obj mock_class
    mock_do  mock_build
    mock_accessor mock_accessors
    mock_getter   mock_getters
    mock_setter   mock_setters
    mock_building
};
no Test::Stream::Exporter;

our @CARP_NOT = (__PACKAGE__, 'Test::Stream::Mock');
my %MOCKS;
my @BUILD;

sub mock_building {
    return unless @BUILD;
    return $BUILD[-1];
}

sub mocked {
    my $proto = shift;
    my $class = blessed($proto) || $proto;

    # Check if we have any mocks.
    my $set = $MOCKS{$class} || return;

    # Remove dead mocks (undef due to weaken)
    pop @$set while @$set && !defined($set->[-1]);

    # Remove the list if it is empty
    delete $MOCKS{$class} unless @$set;

    # Return the controls (may be empty list)
    return @$set;
}

sub _delegate {
    my ($args) = @_;

    my $do    = __PACKAGE__->can('mock_do');
    my $obj   = __PACKAGE__->can('mock_obj');
    my $class = __PACKAGE__->can('mock_class');
    my $build = __PACKAGE__->can('mock_build');

    return $obj unless @$args;

    my ($proto, $arg1) = @$args;

    return $obj if ref($proto) && !blessed($proto);

    if (blessed($proto)) {
        return $class unless $proto->isa('Test::Stream::Mock');
        return $build if $arg1 && ref($arg1) && reftype($arg1) eq 'CODE';
    }

    return $class if $proto =~ m/(?:::|')/;
    return $class if $proto =~ m/^_*[A-Z]/;

    return $do if Test::Stream::Mock->can($proto);

    if (my $sub = __PACKAGE__->can("mock_$proto")) {
        shift @$args;
        return $sub;
    }

    return undef;
}

sub mock {
    croak "undef is not a valid first argument to mock()"
        if @_ && !defined($_[0]);

    my $sub = _delegate(\@_);

    croak "'$_[0]' does not look like a package name, and is not a valid control method"
        unless $sub;

    $sub->(@_);
}

sub mock_build {
    my ($control, $sub) = @_;

    croak "mock_build requires a Test::Stream::Mock object as its first argument"
        unless $control && blessed($control) && $control->isa('Test::Stream::Mock');

    croak "mock_build requires a coderef as its second argument"
        unless $sub && ref($sub) && reftype($sub) eq 'CODE';

    push @BUILD => $control;
    my ($ok, $err) = &try($sub);
    pop @BUILD;
    die $err unless $ok;
}

sub mock_do {
    my ($meth, @args) = @_;

    croak "Not currently building a mock"
        unless @BUILD;

    my $build = $BUILD[-1];

    croak "'$meth' is not a valid action for mock_do()"
        if $meth =~ m/^_/ || !$build->can($meth);

    $build->$meth(@args);
}

sub mock_obj {
    my ($proto) = @_;

    if ($proto && ref($proto) && reftype($proto) ne 'CODE') {
        shift @_;
    }
    else {
        $proto = {};
    }

    my $class = _generate_class();
    my $control;

    if (@_ == 1 && reftype($_[0]) eq 'CODE') {
        my $orig = shift @_;
        $control = mock_class(
            $class,
            sub {
                my $c = mock_building;

                # We want to do these BEFORE anything that the sub may do.
                $c->block_load(1);
                $c->purge_on_destroy(1);
                $c->autoload(1);

                $orig->(@_);
            },
        );
    }
    else {
        $control = mock_class(
            $class,
            # Do these before anything the user specified.
            block_load       => 1,
            purge_on_destroy => 1,
            autoload         => 1,
            @_,
        );
    }

    my $new = bless($proto, $control->class);

    # We need to ensure there is a reference to the control object, and we want
    # it to go away with the object. 
    $new->{'~~MOCK~CONTROL~~'} = $control;
    return $new;
}

sub _generate_class {
    my $prefix = __PACKAGE__;

    for (1 .. 100) {
        my $postfix = join '', map { chr(rand(26) + 65) } 1 .. 32;
        my $class = $prefix . '::__TEMP__::' . $postfix;
        my $file = $class;
        $file =~ s{::}{/}g;
        $file .= '.pm';
        next if $INC{$file};
        my $stash = do { no strict 'refs'; \%{"${class}\::"} };
        next if keys %$stash;
        return $class;
    }

    croak "Could not generate a unique class name after 100 attempts";
}

sub mock_class {
    my $proto = shift;
    my $class = blessed($proto) || $proto;
    my @args = @_;

    my $caller = [caller(0)];
    my $void   = !defined(wantarray);
    my $vars   = Test::Stream::Workflow::Runner->VARS;
    my $build  = workflow_build();
    my $meta   = Test::Stream::Workflow::Meta->get($caller->[0]);

    croak "mock_class should not be called in a void context except in a workflow"
        unless $void || $vars || $build || $meta;

    my $builder = sub {
        my ($parent) = reverse mocked($class);
        my $control;

        if (@args == 1 && ref($args[0]) && reftype($args[0]) eq 'CODE') {
            $control = Test::Stream::Mock->new(class => $class);
            mock_build($control, @args);
        }
        else {
            $control = Test::Stream::Mock->new(class => $class, @args);
        }

        if ($parent) {
            $control->{parent} = $parent;
            weaken($parent->{child} = $control);
        }

        $MOCKS{$class} ||= [];
        push @{$MOCKS{$class}} => $control;
        weaken($MOCKS{$class}->[-1]);

        return $control;
    };

    return $builder->() unless $void;

    my $set_vars = sub {
        $vars ||= Test::Stream::Workflow::Runner->VARS;
        $vars->{(__PACKAGE__)} ||= {};
        $vars->{(__PACKAGE__)}->{$class} = $builder->();
    };

    return $set_vars->() if $vars;

    $build ||= $meta->unit;

    my $now = $builder->();
    $build->add_post(sub { $now = undef });

    $build->add_buildup(
        Test::Stream::Workflow::Unit->new(
            name       => "Mock $class",
            package    => $caller->[0],
            file       => $caller->[1],
            start_line => $caller->[2],
            end_line   => $caller->[2],
            type       => 'single',
            primary    => $set_vars,
        ),
    );

    return;
}

sub mock_accessors {
    return map {( $_ => Test::Stream::HashBase->gen_accessor($_) )} @_;
}

sub mock_accessor {
    my ($field) = @_;
    return Test::Stream::HashBase->gen_accessor($field);
}

sub mock_getters {
    my ($prefix, @list) = @_;
    return map {( "$prefix$_" => Test::Stream::HashBase->gen_getter($_) )} @list;
}

sub mock_getter {
    my ($field) = @_;
    return Test::Stream::HashBase->gen_getter($field);
}

sub mock_setters {
    my ($prefix, @list) = @_;
    return map {( "$prefix$_" => Test::Stream::HashBase->gen_setter($_) )} @list;
}

sub mock_setter {
    my ($field) = @_;
    return Test::Stream::HashBase->gen_setter($field);
}

1;
