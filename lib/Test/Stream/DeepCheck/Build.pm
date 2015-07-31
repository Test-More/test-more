package Test::Stream::DeepCheck::Build;
use strict;
use warnings;

use Test::Stream::Exporter;
default_exports qw/get_build push_build pop_build build/;
no Test::Stream::Exporter;

use Test::Stream::Block;

use Test::Stream::Util qw/try/;
use Carp qw/croak/;

my @BUILD;

sub get_build { @BUILD ? $BUILD[-1] : undef }
sub push_build { push @BUILD => $_[0] }

sub pop_build {
    return pop @BUILD if @BUILD && $BUILD[-1] == $_[0];
    my $have = @BUILD ? "$BUILD[-1]" : 'undef';
    my $want = $_[0]  ? "$_[0]"      : 'undef';
    croak "Attempted to pop incorrect build, have $have, tried to pop $want";
}

sub build {
    my ($class, $code) = @_;

    my @caller = caller(1);

    my $block = Test::Stream::Block->new(
        coderef => $code,
        caller  => \@caller,
    );
    my $build = $class->new(
        file       => $block->file,
        start_line => $block->start_line,
        end_line   => $block->end_line,
    );

    push_build($build);
    my ($ok, $err) = try { $code->($build) };
    pop_build($build);
    die $err unless $ok;

    return $build;
}


1;
