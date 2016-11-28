package Test2::Util::Term;
use strict;
use warnings;

our $VERSION = '0.000062';

use Test2::Util qw/try/;

use Importer Importer => 'import';
our @EXPORT_OK = qw/term_size USE_GCS USE_TERM_READKEY uni_length/;

sub DEFAULT_SIZE() { 80 }

my ($trk) = try { require Term::ReadKey };
$trk &&= Term::ReadKey->can('GetTerminalSize');

if ($trk) {
    *USE_TERM_READKEY = sub() { 1 };
    *term_size = sub {
        return $ENV{T2_TERM_SIZE} if $ENV{T2_TERM_SIZE};

        my $total;
        try {
            my @warnings;
            {
                local $SIG{__WARN__} = sub { push @warnings => @_ };
                ($total) = Term::ReadKey::GetTerminalSize(*STDOUT);
            }
            @warnings = grep { $_ !~ m/Unable to get Terminal Size/ } @warnings;
            warn @warnings if @warnings;
        };
        return DEFAULT_SIZE if !$total;
        return DEFAULT_SIZE if $total < DEFAULT_SIZE;
        return $total;
    };
}
else {
    *USE_TERM_READKEY = sub() { 0 };
    *term_size = sub {
        return $ENV{T2_TERM_SIZE} if $ENV{T2_TERM_SIZE};
        return DEFAULT_SIZE;
    };
}

my ($gcs, $err) = try { require Unicode::GCString };

if ($gcs) {
    *USE_GCS    = sub() { 1 };
    *uni_length = sub   { Unicode::GCString->new($_[0])->columns };
}
else {
    *USE_GCS    = sub() { 0 };
    *uni_length = sub   { length($_[0]) };
}

1;
