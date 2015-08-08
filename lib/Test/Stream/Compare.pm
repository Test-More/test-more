package Test::Stream::Compare;
use strict;
use warnings;

use Test::Stream::Util qw/try/;

use Carp qw/confess croak/;
use Scalar::Util qw/blessed/;

use Test::Stream::Exporter;
export compare => sub {
    my ($got, $check, $convert) = @_;

    $check = $convert->($check)
        unless blessed($check) && $check->isa(__PACKAGE__);

    return $check->run(undef, $got, $convert, {});
};

my @BUILD;

export get_build  => sub { @BUILD ? $BUILD[-1] : undef };
export push_build => sub { push @BUILD => $_[0] };

export pop_build => sub {
    return pop @BUILD if @BUILD && $BUILD[-1] == $_[0];
    my $have = @BUILD ? "$BUILD[-1]" : 'undef';
    my $want = $_[0]  ? "$_[0]"      : 'undef';
    croak "INTERNAL ERROR: Attempted to pop incorrect build, have $have, tried to pop $want";
};

export build => sub {
    my ($class, $code) = @_;

    my @caller = caller(1);

    my $block = Test::Stream::Block->new(
        coderef => $code,
        caller  => \@caller,
    );
    my $build = $class->new(
        file  => $block->file,
        lines => [$block->start_line, $block->end_line],
    );

    die "'$caller[3]\()' should not be called in void context in " . $block->call_detail . "\n"
        unless defined(wantarray);

    push @BUILD => $build;
    my ($ok, $err) = try { $code->($build); 1 };
    pop @BUILD;
    die $err unless $ok;

    return $build;
};
no Test::Stream::Exporter;

use Test::Stream::HashBase(
    accessors => [qw/file lines/]
);

use Test::Stream::Delta;
sub delta_class { 'Test::Stream::Delta' }

sub deltas { }
sub diag   { }
sub got_lines { }

sub operator { '' }
sub verify   { confess "unimplemented" }
sub name     { confess "unimplemented" }

sub render {
    my $self = shift;
    return $self->name;
}

sub run {
    my $self = shift;
    my ($id, $got, $convert, $seen) = @_;

    if ($got) {
        return if $seen->{$got};
        $seen->{$got}++;
    }

    my $ok = $self->verify($got);
    my @deltas = $ok ? $self->deltas($got, $convert, $seen) : ();

    $seen->{$got}-- if $got;

    return if $ok && !@deltas;

    return $self->delta_class->new(
        verified => $ok,
        id       => $id,
        got      => $got,
        check    => $self,
        children => \@deltas,
    );
}

1;
