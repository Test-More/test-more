package Test::More::DeepCheck;
use strict;
use warnings;

use Test::Stream::ArrayBase;
BEGIN {
    accessors qw/seen/;
    Test::Stream::ArrayBase->cleanup;
}

sub init {
    $_[0]->[SEEN] ||= [{}];
}

my %PAIRS = ( '{' => '}', '[' => ']' );
my $DNE = bless [], 'Does::Not::Exist';

sub is_dne { ref $_[-1] eq ref $DNE }
sub dne { $DNE };

sub preface { "" };

sub format_stack {
    my $self = shift;
    my $start = $self->STACK_START;
    my $end   = @$self - 1;

    my @Stack = @{$self}[$start .. $end];

    my @parts1 = ('     $got');
    my @parts2 = ('$expected');

    my $did_arrow = 0;
    for my $entry (@Stack) {
        next unless $entry;
        my $type = $entry->{type} || '';
        my $idx  = $entry->{idx};
        my $key  = $entry->{key};
        my $wrap = $entry->{wrap};

        if ($type eq 'HASH') {
            unless ($did_arrow) {
                push @parts1 => '->';
                push @parts2 => '->';
                $did_arrow++;
            }
            push @parts1 => "{$idx}";
            push @parts2 => "{$idx}";
        }
        elsif ($type eq 'OBJECT') {
            push @parts1 => '->';
            push @parts2 => '->';
            push @parts1 => "$idx()";
            push @parts2 => "{$idx}";
            $did_arrow = 0;
        }
        elsif ($type eq 'ARRAY') {
            unless ($did_arrow) {
                push @parts1 => '->';
                push @parts2 => '->';
                $did_arrow++;
            }
            push @parts1 => "[$idx]";
            push @parts2 => "[$idx]";
        }
        elsif ($type eq 'REF') {
            unshift @parts1 => '${';
            unshift @parts2 => '${';
            push @parts1 => '}';
            push @parts2 => '}';
        }

        if ($wrap) {
            my $pair = $PAIRS{$wrap};
            unshift @parts1 => $wrap;
            unshift @parts2 => $wrap;
            push @parts1 => $pair;
            push @parts2 => $pair;
        }
    }

    my $error = $Stack[-1]->{error};
    chomp($error) if $error;

    my @vals = @{$Stack[-1]{vals}}[0, 1];
    my @vars = (
        join('', @parts1),
        join('', @parts2),
    );

    my $out = $self->preface;
    for my $idx (0 .. $#vals) {
        my $val = $vals[$idx];
        $vals[$idx] =
              !defined $val ? 'undef'
            : is_dne($val)  ? "Does not exist"
            : ref $val      ? "$val"
            :                 "'$val'";
    }

    $out .= "$vars[0] = $vals[0]\n";
    $out .= "$vars[1] = $vals[1]\n";
    $out .= "$error\n" if $error;

    $out =~ s/^/    /msg;
    return $out;
}

1;
