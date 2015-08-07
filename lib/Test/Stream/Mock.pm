package Test::Stream::Mock;
use strict;
use warnings;

use Scalar::Util qw/weaken reftype blessed/;

use Carp qw/croak confess/;
our @CARP_NOT = (__PACKAGE__, 'Test::Stream::Mock', 'Test::Stream::Workflow');

use Test::Stream::HashBase(
    accessors => [qw/class parent child _purge_on_destroy _blocked_load _symbols/],
    no_new    => 1,
);

sub new {
    my $class = shift;

    croak "Called new() on a blessed instance, did you mean to call \$control->class->new()?"
        if blessed($class);

    my $self = bless({}, $class);

    my @sets;
    while (my $arg = shift @_) {
        my $val = shift @_;

        if ($class->can(uc($arg))) {
            $self->{$arg} = $val;
            next;
        }

        push @sets => [$arg, $val];
    }

    croak "The 'class' field is required"
        unless $self->{+CLASS};

    for my $set (@sets) {
        my ($meth, $val) = @$set;
        my $type = reftype($val);

        confess "'$meth' is not a valid method name"
            unless $self->can($meth);

        if (!$type) {
            $self->$meth($val);
        }
        elsif($type eq 'HASH') {
            $self->$meth(%$val);
        }
        elsif($type eq 'ARRAY') {
            $self->$meth(@$val);
        }
        else {
            croak "'$val' is not a valid argument for '$meth'"
        }
    }

    return $self;
}

sub _check {
    return unless $_[0]->{+CHILD};
    croak "There is an active child controller, cannot proceed";
}

sub purge_on_destroy {
    my $self = shift;
    ($self->{+_PURGE_ON_DESTROY}) = @_ if @_;
    return $self->{+_PURGE_ON_DESTROY};
}

sub stash {
    my $self = shift;
    my $class = $self->{+CLASS};

    no strict 'refs';
    return \%{"${class}\::"};
}

sub file {
    my $self = shift;
    my $file = $self->class;
    $file =~ s{(::|')}{/}g;
    $file .= ".pm";
    return $file;
}

sub block_load {
    my $self = shift;
    $self->_check();

    my $file = $self->file;

    croak "Cannot block the loading of module '" . $self->class . "', already loaded in file $INC{$file}"
        if $INC{$file};

    $INC{$file} = __FILE__;

    $self->{+_BLOCKED_LOAD} = 1;
}

my %NEW = (
    hash => sub {
        my ($class, %params) = @_;
        return bless \%params, $class;
    },
    ref => sub {
        my ($class, $params) = @_;
        return bless $params, $class;
    },
    ref_copy => sub {
        my ($class, $params) = @_;
        return bless {%$params}, $class;
    },
);

sub override_constructor {
    my $self = shift;
    my ($name, $type) = @_;
    $self->_check();

    my $sub = $NEW{$type}
        || croak "'$type' is not a known constructor type";

    $self->override($name => $sub);
}

sub add_constructor {
    my $self = shift;
    my ($name, $type) = @_;
    $self->_check();

    my $sub = $NEW{$type}
        || croak "'$type' is not a known constructor type";

    $self->add($name => $sub);
}

sub autoload {
    my $self = shift;
    $self->_check();
    my $class = $self->class;
    my $stash = $self->stash;

    croak "Class '$class' already has an AUTOLOAD"
        if $stash->{AUTOLOAD} && *{$stash->{AUTOLOAD}}{CODE};

    # Weaken this reference so that AUTOLOAD does not prevent its own
    # destruction.
    weaken(my $c = $self);

    my ($file, $line) = (__FILE__, __LINE__ + 3);
    my $sub = eval <<EOT || die $@;
package $class;
#line $line "$file (Generated AUTOLOAD)"
our \$AUTOLOAD;
    sub {
        my (\$self) = \@_;
        my (\$pkg, \$name) = (\$AUTOLOAD =~ m/^(.*)::([^:]+)\$/g);
        \$AUTOLOAD = undef;

        return if \$name eq 'DESTROY';
        my \$sub = Test::Stream::HashBase->gen_accessor(\$name);

        \$c->add(\$name => \$sub);
        goto &\$sub;
    }
EOT

    $self->add(AUTOLOAD => $sub);
}

sub before {
    my $self = shift;
    my ($name, $sub) = @_;
    $self->_check();
    my $orig = $self->current($name);
    $self->_inject(0, $name => sub { $sub->(@_); $orig->(@_) });
}

sub after {
    my $self = shift;
    my ($name, $sub) = @_;
    $self->_check();
    my $orig = $self->current($name);
    $self->_inject(0, $name => sub {
        my @out;

        my $want = wantarray;

        if ($want) {
            @out = $orig->(@_);
        }
        elsif(defined $want) {
            $out[0] = $orig->(@_);
        }
        else {
            $orig->(@_);
        }

        $sub->(@_);

        return @out    if $want;
        return $out[0] if defined $want;
        return;
    });
}

sub around {
    my $self = shift;
    my ($name, $sub) = @_;
    $self->_check();
    my $orig = $self->current($name);
    $self->_inject(0, $name => sub { $sub->($orig, @_) });
}

sub add {
    my $self = shift;
    $self->_check();
    $self->_inject(1, @_);
}

sub override {
    my $self = shift;
    $self->_check();
    $self->_inject(0, @_);
}

my %SIG_MAP = (
    '&' => 'CODE',
    '%' => 'HASH',
    '@' => 'ARRAY',
    '$' => 'SCALAR',
);
%SIG_MAP = (
    %SIG_MAP,
    reverse %SIG_MAP,
);

sub _parse_sym {
    my ($sym) = @_;

    my ($name, $type);
    if ($sym =~ m/^(\W)(.+)$/) {
        $name = $2;
        $type = $SIG_MAP{$1}
            || croak "'$1' is not a supported sigil";
    }
    else {
        $name = $sym;
        $type = 'CODE';
    }

    return ($name, $type);
}

sub current {
    my $self = shift;
    my ($sym) = @_;

    my $class = $self->{+CLASS};
    my ($name, $type) = _parse_sym($sym);

    my $stash = $self->stash;
    return unless $stash->{$name};

    no strict 'refs';
    return *{"$class\::$name"}{$type};
}

sub orig {
    my $self = shift;
    my ($sym) = @_;

    $sym = "&$sym" unless $sym =~ m/^[&\$\%\@]/;

    my $syms = $self->{+_SYMBOLS}
        || croak "No symbols have been mocked yet";

    my $ref = $syms->{$sym};

    use Data::Dumper;
    croak "Symbol '$sym' is not mocked"
        unless $ref && @$ref;

    my ($orig) = @$ref;

    return $orig;
}

sub _parse_inject {
    my $self = shift;
    my ($param, $arg) = @_;

    if ($param =~ m/^-(.*)$/) {
        my $sym = $1;
        my $sig = $SIG_MAP{reftype($arg)};
        my $ref = $arg;
        return ($sig, $sym, $ref);
    }

    return ('&', $param, $arg)

    if ref($arg) && reftype($arg) eq 'CODE';

    my ($is, $field, $val);

    if (!ref($arg)) {
        $is    = $arg if $arg =~ m/^(rw|ro|wo)$/;
        $field = $param;
    }
    elsif (reftype($arg) eq 'HASH') {
        $field = delete $arg->{field} || $param;

        $val = delete $arg->{val};
        $is  = delete $arg->{is};

        croak "Cannot specify 'is' and 'val' together" if $val && $is;

        $is ||= $val ? 'val' : 'rw';

        croak "The following keys are not valid when defining a mocked sub with a hashref: " . join(", " => keys %$arg)
            if keys %$arg;
    }

    confess "'$arg' is not a valid argument when defining a mocked sub"
        unless $is;

    my $sub;
    if ($is eq 'rw') {
        $sub = Test::Stream::HashBase->gen_accessor($field);
    }
    elsif ($is eq 'ro') {
        $sub = Test::Stream::HashBase->gen_getter($field);
    }
    elsif ($is eq 'wo') {
        $sub = Test::Stream::HashBase->gen_setter($field);
    }
    else { # val
        $sub = sub { $val };
    }

    return ('&', $param, $sub);
}

sub _inject {
    my $self = shift;
    my ($add, @pairs) = @_;

    my $class = $self->{+CLASS};

    $self->{+_SYMBOLS} ||= {};
    my $syms = $self->{+_SYMBOLS};

    while (my $param = shift @pairs) {
        my $arg = shift @pairs;
        my ($sig, $sym, $ref) = $self->_parse_inject($param, $arg);
        my $orig = $self->current("$sig$sym");

        croak "Cannot override '$sig$class\::$sym', symbol is not already defined"
            unless $orig || $add;

        # Cannot be too sure about scalars in globs
        croak "Cannot add '$sig$class\::$sym', symbol is already defined"
            if $add && $orig
            && (reftype($orig) ne 'SCALAR' || defined($$orig));

        $syms->{"$sig$sym"} ||= [];
        push @{$syms->{"$sig$sym"}} => $orig; # Might be undef, thats expected

        no strict 'refs';
        no warnings 'redefine';
        *{"$class\::$sym"} = $ref;
    }

    return;
}

sub _set_or_unset {
    my $self = shift;
    my ($sym, $set) = @_;

    my $class = $self->{+CLASS};
    my ($name, $type) = _parse_sym($sym);

    if (defined $set) {
        no strict 'refs';
        no warnings 'redefine';
        return *{"$class\::$name"} = $set;
    }

    # Damn, need to clear it, this gets complicated :-(
    my $stash = $self->stash;
    local *__ORIG__ = do { no strict 'refs'; *{"$class\::$name"} };
    delete $stash->{$name};

    for my $slot (qw/CODE SCALAR HASH ARRAY/) {
        next if $slot eq $type;
        no strict 'refs';
        no warnings 'redefine';
        *{"$class\::$name"} = *__ORIG__{$slot} if defined(*__ORIG__{$slot});
    }

    return undef;
}

sub restore {
    my $self = shift;
    my ($sym) = @_;
    $self->_check();

    $sym = "&$sym" unless $sym =~ m/^[&\$\%\@]/;

    my $syms = $self->{+_SYMBOLS}
        || croak "No symbols are mocked";

    my $ref = $syms->{$sym};

    croak "Symbol '$sym' is not mocked"
        unless $ref && @$ref;

    my $old = pop @$ref;
    delete $syms->{$sym} unless @$ref;

    return $self->_set_or_unset($sym, $old);
}

sub reset {
    my $self = shift;
    my ($sym) = @_;
    $self->_check();

    $sym = "&$sym" unless $sym =~ m/^[&\$\%\@]/;

    my $syms = $self->{+_SYMBOLS}
        || croak "No symbols are mocked";

    my $ref = delete $syms->{$sym};

    croak "Symbol '$sym' is not mocked"
        unless $ref && @$ref;

    my ($old) = @$ref;

    return $self->_set_or_unset($sym, $old);
}

sub reset_all {
    my $self = shift;
    $self->_check();

    my $syms = $self->{+_SYMBOLS} || return;

    $self->reset($_) for keys %$syms;

    delete $self->{+_SYMBOLS};
}

sub _purge {
    my $self = shift;
    my $stash = $self->stash;
    delete $stash->{$_} for keys %$stash;
}

sub DESTROY {
    my $self = shift;

    $self->reset_all if $self->{+_SYMBOLS};

    delete $INC{$self->file} if $self->{+_BLOCKED_LOAD};

    $self->_purge if $self->{+_PURGE_ON_DESTROY};
}

1;
