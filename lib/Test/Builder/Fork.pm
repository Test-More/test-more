package Test::Builder::Fork;
use strict;
use warnings;

use Carp qw/confess/;
use Scalar::Util qw/blessed/;
use File::Temp();
use Data::Dumper;

sub tmpdir { shift->{tmpdir} }
sub pid    { shift->{pid}    }

sub new {
    my $class = shift;

    my $dir = File::Temp::tempdir(CLEANUP => 0) || die "Could not get a temp dir";

    my $self = bless { tmpdir => $dir, pid => $$ }, $class;

    return $self;
}

sub handler {
    my $self = shift;

    my $id = 1;

    return sub {
        my ($item) = @_;

        confess "Did not get a valid Test::Builder::Result object! ($item)"
            unless $item && blessed($item) && $item->isa('Test::Builder::Result');

        # Find parent-most TB object and get PID
        my $root = Test::Builder->new;
        while($root->parent) { $root = $root->parent }
        return 0 if $$ eq $root->pid;

        # First write the file, then rename it so that it is not read before it is ready.
        my $name =  $self->tmpdir . "/$$-" . $id++;
        open(my $fh, '>', $name) || die "Could not create temp file";
        local $Data::Dumper::Indent = 0;
        print $fh Dumper($item);
        close $fh;
        rename($name, "$name.ready") || die "Could not rename file";

        return 1;
    };
}

sub cull {
    my $self = shift;
    my $dir = $self->tmpdir;

    opendir(my $dh, $dir) || die "could not open temp dir!";
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        next unless $file =~ m/\.ready$/;

        my $obj = eval { my $VAR1; do "$dir/$file" } || die "Failed to open $file: $@";
        die "Empty result object found" unless $obj;

        my $tb = Test::Builder->new;
        confess "cull() cannot be called in a child builder!" if $tb->parent;
        $tb->stream()->push($obj);

        if ($ENV{TEST_KEEP_TMP_DIR}) {
            rename("$dir/$file", "$dir/$file.complete") || die "Could not rename file";
        }
        else {
            unlink("$dir/$file") || die "Could not unlink file: $file";
        }
    }
    closedir($dh);
}

sub DESTROY {
    my $self = shift;

    return unless $$ == $self->pid;

    my $dir = $self->tmpdir;

    if ($ENV{TEST_KEEP_TMP_DIR}) {
        print STDERR "# Not removing temp dir: $dir\n";
        return;
    }

    opendir(my $dh, $dir) || die "Could not open temp dir!";
    while(my $file = readdir($dh)) {
        next if $file =~ m/^\.+$/;
        unlink("$dir/$file") || die "Could not unlink file: $file";
    }
    closedir($dh);
    rmdir($dir);
}

1;
