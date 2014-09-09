package Test::Stream::IOSets;
use strict;
use warnings;

use Test::Stream::Util qw/protect/;

init_legacy();

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    $self->reset_legacy;

    return $self;
}

sub init_encoding {
    my $self = shift;
    my ($name, @handles) = @_;

    unless($self->{$name}) {
        my ($out, $fail, $todo);

        if (@handles) {
            ($out, $fail, $todo) = @handles;
        }
        else {
            ($out, $fail) = $self->open_handles();
        }

        binmode($out,  ":encoding($name)");
        binmode($fail, ":encoding($name)");

        $self->{$name} = [$out, $fail, $todo || $out];
    }

    return $self->{$name};
}

my $LEGACY;
sub hard_reset { $LEGACY = undef }
sub init_legacy {
    return if $LEGACY;

    my ($out, $err) = open_handles();

    _copy_io_layers(\*STDOUT, $out);
    _copy_io_layers(\*STDERR, $err);

    _autoflush($out);
    _autoflush($err);

    # LEGACY, BAH!
    # This is necessary to avoid out of sequence writes to the handles
    _autoflush(\*STDOUT);
    _autoflush(\*STDERR);

    $LEGACY = [$out, $err, $out];
}

sub reset_legacy {
    my $self = shift;
    init_legacy() unless $LEGACY;
    my ($out, $fail, $todo) = @$LEGACY;
    $self->{legacy} = [$out, $fail, $todo];
}

sub _copy_io_layers {
    my($src, $dst) = @_;

    protect {
        require PerlIO;
        my @src_layers = PerlIO::get_layers($src);
        _apply_layers($dst, @src_layers) if @src_layers;
    };

    return;
}

sub _autoflush {
    my($fh) = shift;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;

    return;
}

sub open_handles {
    open( my $out, ">&STDOUT" ) or die "Can't dup STDOUT:  $!";
    open( my $err, ">&STDERR" ) or die "Can't dup STDERR:  $!";

    _autoflush($out);
    _autoflush($err);

    return ($out, $err);
}

sub _apply_layers {
    my ($fh, @layers) = @_;
    my %seen;
    my @unique = grep { $_ !~ /^(unix|perlio)$/ && !$seen{$_}++ } @layers;
    binmode($fh, join(":", "", "raw", @unique));
}

1;
