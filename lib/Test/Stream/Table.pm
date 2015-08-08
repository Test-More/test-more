package Test::Stream::Table;
use strict;
use warnings;

use List::Util qw/min max sum/;

use Test::Stream::Util qw/term_size/;

use Test::Stream::Exporter;
exports qw/table/;
no Test::Stream::Exporter;

my %CHAR_MAP = (
    "\n" => '\\n',
    "\t" => '\\t',
    "\r" => '\\r',
);
sub show_char {
    my ($char) = @_;
    return $CHAR_MAP{$char} || "\\N{U+" . sprintf("\%X", ord($char)) . "}";
}

sub sanitize {
    for (@_) {
        next unless $_;
        s/([\t\p{Zl}\p{C}\p{Zp}])/show_char($1)/ge; # All whitespace except normal space
        s/(\s)$/show_char($1)/ge;                   # trailing space
    }
    return @_;
}

sub resize {
    my ($max, $show, $lengths) = @_;

    my $fair = int($max / @$show); # Fair size for all rows

    my $used = 0;
    my @resize;
    for my $i (@$show) {
        my $size = $lengths->[$i];
        if ($size <= $fair) {
            $used += $size;
            next;
        }

        push @resize => $i;
    }

    my $new_max = $max - $used;
    my $new_fair = int($new_max / @resize);
    $lengths->[$_] = $new_fair for @resize;
}

sub BORDER_SIZE() { 4 }    # '| ' and ' |' borders
sub PAD_SIZE()    { 4 }    # Extra arbitrary padding
sub DIV_SIZE()    { 3 }    # ' | ' column delimiter

sub table {
    my %params = @_;
    my $header   = $params{header};
    my $rows     = $params{rows};
    my $collapse = $params{collapse};

    my $last = ($header ? scalar @$header : max(map { scalar @{$_} } @$rows)) - 1;
    my @all = 0 .. $last;

    my @lengths;
    for my $row (@$rows) {
        sanitize(@$row);
        $lengths[$_] = max(length($row->[$_]), $lengths[$_] || 0) for @all;
    }

    # How many columns are we showing?
    my @show = $collapse ? (grep { $lengths[$_] } @all) : (@all);

    # Titles should fit
    if ($header) {
        for my $i (@all) {
            next if $collapse && !$lengths[$i];
            $lengths[$i] = max(length($header->[$i]), $lengths[$i] || 0);
        }
    }

    # Figure out size of screen, and a fair size for each column.
    my $divs     = @show * DIV_SIZE();    # size of the dividers combined
    my $max_size = term_size()            # initial terminal size
                 - BORDER_SIZE()          # Subtract the border
                 - PAD_SIZE()             # subtract the padding
                 - $divs;                 # Subtract dividers

    # Make sure we do not spill off the screen
    resize($max_size, \@show, \@lengths) if sum(@lengths) > $max_size;

    # Put together borders and row template
    my $border   = join '-', '+', map { '-' x $lengths[$_], "+" } @show;
    my $row_tmpl = join ' ', '|', map { my $l = $lengths[$_]; "\%-${l}.${l}s |" } @show;

    my $span = 0;
    my @new_rows;
    while (@$rows) {
        my @new;
        my $row = $rows->[0];
        my $more = 0;

        for my $i (@show) {
            $row->[$i] .= "";
            unless (defined($row->[$i]) && length("$row->[$i]")) {
                push @new => '';
                next; # This is important to avoid $more++ if the col is already empty.
            }

            if ($span || length($row->[$i]) <= $lengths[$i]) {
                push @new => substr($row->[$i], 0, $lengths[$i], '');
            }
            else {
                push @new => "<LENGTH: " . length($row->[$i]) . ">";
            }

            # Make sure we keep going if there is more, and also add one more for whitespace
            $more++ if length($row->[$i]) || ($span && @$rows > 1);
        }
        $span++;

        push @new_rows => \@new;
        next if $more;
        shift @$rows;
        $span = 0;
    }

    return (
        $header ? (
            $border,
            sprintf($row_tmpl, @$header[@show]),
        ) : (),

        $border,

        (map {sprintf($row_tmpl, @{$_})} @new_rows),

        $border,
    );
}

1;
