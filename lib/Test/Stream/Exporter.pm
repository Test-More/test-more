package Test::Stream::Exporter;
use strict;
use warnings;

{
    my $META = {};
    sub TB_EXPORTER_META { $META };
}

sub export;
sub exports;
sub unexports;

# Test::Stream::Carp uses this module.
sub croak   { require Carp; goto &Carp::croak }
sub confess { require Carp; goto &Carp::confess }

sub import {
    my $class = shift;
    my $caller = caller;

    unless (package_sub($caller, 'TB_EXPORTER_META')) {
        my $meta = { export => {}, unexport => {} };
        no strict 'refs';
        *{"$caller\::TB_EXPORTER_META"} = sub { $meta };
    }

    $class->export_to($caller, @_);
}

exports   qw/export exports unexport unexports cleanup export_to package_sub/;
unexports qw/export exports unexport unexports/;

export import => sub {
    my $class = shift;
    my $caller = caller;
    my @args = @_;

    my $stash = $class->before_import($caller, \@args) if $class->can('before_import');
    $class->export_to($caller, @args);
    $class->after_import($caller, $stash, @args) if $class->can('after_import');
};

sub export_to {
    my $class = shift;
    my ($dest, @imports) = @_;

    my $is_exporter = package_sub($class, 'TB_EXPORTER_META');
    croak "$class is not an exporter!?" unless $is_exporter;
    my $meta = $is_exporter->();

    my (@include, %exclude);
    for my $import (@imports) {
        if ($import =~ m/^!(.*)$/) {
            $exclude{$1}++;
        }
        else {
            push @include => $import;
        }
    }

    @include = keys %{$meta->{export}} unless @include;

    for my $name (@include) {
        next if $exclude{$name};
        my $ref = $meta->{export}->{$name} || croak "$class does not export $name";
        no strict 'refs';
        $name =~ s/^[\$\@\%\&]//;
        *{"$dest\::$name"} = $ref;
    }
}

sub cleanup {
    my $class = shift;
    my $caller = caller;

    croak "Cannot cleanup ourselves!" if $class eq $caller;

    my $is_exporter = package_sub($class, 'TB_EXPORTER_META');
    croak "$class is not an exporter!?" unless $is_exporter;
    my $meta = $is_exporter->();

    my @remove = @_;
    @remove = keys %{$meta->{unexport}} unless @remove;

    for my $name (@remove) {
        croak "$class cannot unexport $name"
            unless $meta->{unexport}->{$name};

        my $ref = package_sub($caller, $name);
        if (!$ref) {
            croak "cannot unexport $name: Not found!" if @_; # Only when a list is specified
            next;
        }

        unless($ref == $meta->{export}->{$name}) {
            croak "cannot unexport $name: Not provided by $class" if @_;
            next;
        }

        no strict 'refs';
        no warnings 'redefine';
        *{"$caller\::$name"} = sub { croak "sub '$caller\::$name' has been removed" };
    }
}

sub export {
    my ($name, $ref) = @_;
    my $caller = caller;
    my $is_exporter = package_sub($caller, 'TB_EXPORTER_META');
    croak "$caller is not an exporter!?" unless $is_exporter;
    my $meta = $is_exporter->();
    _export($caller, $meta, $name, $ref);
}

sub exports {
    my $caller = caller;
    my $is_exporter = package_sub($caller, 'TB_EXPORTER_META');
    croak "$caller is not an exporter!?" unless $is_exporter;
    my $meta = $is_exporter->();
    _export($caller, $meta, $_) for @_;
}

sub unexport {
    my $caller = caller;
    my $is_exporter = package_sub($caller, 'TB_EXPORTER_META');
    croak "$caller is not an exporter!?" unless $is_exporter;
    my $meta = $is_exporter->();
    _unexport($caller, $meta, $_[0]);
}

sub unexports {
    my $caller = caller;
    my $is_exporter = package_sub($caller, 'TB_EXPORTER_META');
    croak "$caller is not an exporter!?" unless $is_exporter;
    my $meta = $is_exporter->();
    _unexport($caller, $meta, $_) for @_;
}

sub _export {
    my ($class, $meta, $name, $ref) = @_;
    next unless $name;

    my ($syg) = ($name =~ m/^(\$|\@|\%)/i);
    croak "You must provide a reference for '$syg' exports" if $syg && !$ref;
    $ref ||= package_sub($class, $name) || croak "$class has no sub named $name";

    croak "$class already exports something called '$name'" if $meta->{export}->{$name};
    $meta->{export}->{$name} = $ref;
    no strict 'refs';
    push @{"$class\::EXPORT"} => $name;
}

sub _unexport {
    my ($caller, $meta, $name) = @_;
    $meta->{unexport}->{$name}++;
}

sub package_sub {
    my ($pkg, $sub) = @_;
    confess "you must specify a package" unless $pkg;
    confess "you must specify a subname" unless $sub;
    no warnings 'once';
    no strict 'refs';
    my $globref = \*{"$pkg\::$sub"};
    return *$globref{CODE} || undef;
}

1;

