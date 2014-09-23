package Test::Stream::Exporter;
use strict;
use warnings;

use Test::Stream::PackageUtil;
use Test::Stream::Exporter::Meta;

sub export;
sub exports;
sub default_export;
sub default_exports;

# Test::Stream::Carp uses this module.
sub croak   { require Carp; goto &Carp::croak }
sub confess { require Carp; goto &Carp::confess }

BEGIN { Test::Stream::Exporter::Meta->new(__PACKAGE__) };

sub import {
    my $class = shift;
    my $caller = caller;

    Test::Stream::Exporter::Meta->new($caller);

    export_to($class, $caller, @_);
}

default_exports qw/export exports default_export default_exports/;
exports         qw/export_to export_meta/;

default_export import => sub {
    my $class = shift;
    my $caller = caller;
    my @args = @_;

    my $stash = $class->before_import($caller, \@args) if $class->can('before_import');
    export_to($class, $caller, @args);
    $class->after_import($caller, $stash, @args) if $class->can('after_import');
};

sub export_meta {
    my $pkg = shift || caller;
    return Test::Stream::Exporter::Meta->get($pkg);
}

sub export_to {
    my $class = shift;
    my ($dest, @imports) = @_;

    my $meta = export_meta($class)
        || croak "$class is not an exporter!?";

    my (@include, %exclude);
    for my $import (@imports) {
        if ($import =~ m/^!(.*)$/) {
            $exclude{$1}++;
        }
        else {
            push @include => $import;
        }
    }

    @include = $meta->default unless @include;

    for my $name (@include) {
        next if $exclude{$name};

        my $ref = $meta->exports->{$name}
            || croak "$class does not export $name";

        no strict 'refs';
        $name =~ s/^[\$\@\%\&]//;
        *{"$dest\::$name"} = $ref;
    }
}

sub cleanup {
    my $pkg = caller;
    package_purge_sym($pkg, map {(CODE => $_)} qw/export exports default_export default_exports/);
}

sub export {
    my ($name, $ref) = @_;
    my $caller = caller;

    my $meta = export_meta($caller) ||
        croak "$caller is not an exporter!?";

    $meta->add($name, $ref);
}

sub exports {
    my $caller = caller;

    my $meta = export_meta($caller) ||
        croak "$caller is not an exporter!?";

    $meta->add($_) for @_;
}

sub default_export {
    my ($name, $ref) = @_;
    my $caller = caller;

    my $meta = export_meta($caller) ||
        croak "$caller is not an exporter!?";

    $meta->add_default($name, $ref);
}

sub default_exports {
    my $caller = caller;

    my $meta = export_meta($caller) ||
        croak "$caller is not an exporter!?";

    $meta->add_default($_) for @_;
}

1;

