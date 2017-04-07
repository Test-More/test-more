package Test2::Formatter::Stream;
use strict;
use warnings;

use Carp qw/confess/;
use Test2::Util qw/pkg_to_file/;

use base qw/Test2::Formatter/;
use Test2::Util::HashBase qw/serializer io _encoding/;

sub hide_buffered { 0 }

sub find_serializer {
    my $class = shift;

    my $serializer = $ENV{TEST2_STREAM_SERIALIZER}
        or confess "No serializer set, either pass one in at construction or set the TEST2_STREAM_SERIALIZER environment variable.";

    my $sclass;
    if ($serializer =~ m/^\+(.*)$/) {
        $sclass = $1;
    }
    else {
        $sclass = __PACKAGE__ . '::Serializer::' . $serializer;
    }

    my $sfile = pkg_to_file($sclass);
    eval { require $sfile } || die "Could not load serializer '$serializer': $@";

    return $sclass->new;
}

sub find_handle {
    my $class = shift;

    my $handle;

    my $is_socket = 0;
    if (my $file = $ENV{TEST2_STREAM_FILE}) {
        require IO::Handle;
        open($handle, '>', $file) or die "Could not open stream file '$file': $!";
    }
    elsif (my $sfile = $ENV{TEST2_STREAM_SOCKET}) {
        require IO::Socket::UNIX;
        my $handle = IO::Socket::UNIX->new(Peer => $sfile) or die "Could not connect to unix socket '$sfile': $!";
        $is_socket = 1;
    }
    elsif (my $port = $ENV{TEST2_STREAM_PORT}) {
        my $addr = $ENV{TEST2_STREAM_ADDR} || 'localhost';
        require IO::Socket::INET;
        $handle = IO::Socket::INET->new(
            PeerAddr => $addr,
            PeerPort => $port,
        );
        $is_socket = 1;
    }

    confess "Could not find destination handle, please pass one to the constructor, or specify one or more of TEST2_STREAM_(FILE|SOCKET|PORT|ADDR) environment variables"
        unless $handle;

    $handle->autoflush(1);

    # For handles that are not true files we send the id alone as the first data (if an ID is provided).
    print $handle "$ENV{TEST2_STREAM_ID}\n"
        if $is_socket && $ENV{TEST2_STREAM_ID};

    return $handle;
}

sub init {
    my $self = shift;

    $self->{+IO}         ||= $self->find_handle;
    $self->{+SERIALIZER} ||= $self->find_serializer;
}

sub encoding {
    my $self = shift;
    my ($enc) = @_;
    $self->{+SERIALIZER}->send($self->{+IO}, {control => {encoding => $enc}});
    $self->set_encoding($enc);
}

sub set_encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;

        # https://rt.perl.org/Public/Bug/Display.html?id=31923
        # If utf8 is requested we use ':utf8' instead of ':encoding(utf8)' in
        # order to avoid the thread segfault.
        if ($enc =~ m/^utf-?8$/i) {
            binmode($self->{+IO}, ":utf8");
        }
        else {
            binmode($self->{+IO}, ":encoding($enc)");
        }
        $self->{+_ENCODING} = $enc;
    }

    return $self->{+_ENCODING};
}

if ($^C) {
    no warnings 'redefine';
    *write = sub {};
}
sub write {
    my ($self, $e, $num, $f) = @_;
    $f ||= $e->facet_data;

    $self->set_encoding($f->{control}->{encoding}) if $f->{control}->{encoding};

    $self->{+SERIALIZER}->send($self->{+IO}, $f, $num, $e);
}

sub DESTROY {
    my $self = shift;
    my $IO = $self->{+IO} or return;
    eval { $IO->flush };
}


1;
