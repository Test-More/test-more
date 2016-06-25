package Test2::Util::Table;
use strict;
use warnings;

our $VERSION = '0.000041';

use Test2::Util::Table::LineBreak();

use List::Util qw/max sum/;
use Test2::Util qw/try/;

our @EXPORT_OK = qw/table term_size/;
use base 'Exporter';

BEGIN {
    my ($ok, $err) = try { require Term::ReadKey };
    $ok &&= Term::ReadKey->can('GetTerminalSize');
    *USE_TERM_READKEY = $ok ? sub() { 1 } : sub() { 0 };
}

sub term_size {
    return $ENV{T2_TERM_SIZE} if $ENV{T2_TERM_SIZE};
    return 80 unless USE_TERM_READKEY;
    my $total;
    try {
        my @warnings;
        local $SIG{__WARN__} = sub { push @warnings => @_ };
        ($total) = Term::ReadKey::GetTerminalSize(*STDOUT);
        @warnings = grep { $_ !~ m/Unable to get Terminal Size/ } @warnings;
        warn @warnings;
    };
    return 80 if !$total;
    return 80 if $total < 80;
    return $total;
}

sub BORDER_SIZE() { 4 }    # '| ' and ' |' borders
sub DIV_SIZE()    { 3 }    # ' | ' column delimiter
sub PAD_SIZE()    { 4 }    # Extra arbitrary padding

my %CHAR_MAP = (
    "\a" => '\\a',
    "\b" => '\\b',
    "\e" => '\\e',
    "\f" => '\\f',
    "\n" => '\\n',
    "\r" => '\\r',
    "\t" => '\\t',
    " "  => ' ',
);

sub char_id {
    my $char = shift;
    return "\\N{U+" . sprintf("\%X", ord($char)) . "}";
}

sub show_char {
    my ($char) = @_;
    return $CHAR_MAP{$char} || char_id($char);
}

sub sanitize {
    for (@_) {
        next unless defined $_;
        s/([\s\t\p{Zl}\p{C}\p{Zp}])/show_char($1)/ge; # All whitespace except normal space
    }
    return @_;
}

sub mark_tail {
    for (@_) {
        next unless defined $_;
        s/([\s\t\p{Zl}\p{C}\p{Zp}])$/$1 eq ' ' ? char_id($1) : show_char($1)/e;
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

sub table {
    my %params = @_;
    my $header      = $params{header};
    my $rows        = $params{rows};
    my $collapse    = $params{collapse};
    my $maxwidth    = $params{max_width} || term_size();
    my $sanitize    = $params{sanitize};
    my $mark_tail   = $params{mark_tail};
    my $no_collapse = $params{no_collapse} || [];

    $no_collapse = { map {($_ => 1)} @$no_collapse };

    my $last = ($header ? scalar @$header : max(map { scalar @{$_} } @$rows)) - 1;
    my @all = 0 .. $last;

    my $uniwarn = 0;
    my @lengths;
    for my $row (@$rows) {
        $uniwarn ||= m/[^\x00-\x7F]/ for grep { defined($_) } @$row;
        sanitize(@$row)  if $sanitize;
        mark_tail(@$row) if $mark_tail;
        @$row = map { Test2::Util::Table::LineBreak->new(string => defined($row->[$_]) ? "$row->[$_]" : '') } @all;
        $lengths[$_] = max($row->[$_]->columns, $lengths[$_] || 0) for @all;
    }

    # How many columns are we showing?
    my @show = $collapse ? (grep { $lengths[$_] || $no_collapse->{$_} } @all) : (@all);

    # Titles should fit
    if ($header) {
        @$header = map {Test2::Util::Table::LineBreak->new(string => "$_")} @$header;
        for my $i (@all) {
            next if $collapse && !$lengths[$i] && !$no_collapse->{$i};
            $lengths[$i] = max($header->[$i]->columns, $lengths[$i] || 0);
        }
    }

    # Figure out size of screen, and a fair size for each column.
    my $divs     = @show * DIV_SIZE();    # size of the dividers combined
    my $max_size = $maxwidth              # initial terminal size
                 - BORDER_SIZE()          # Subtract the border
                 - PAD_SIZE()             # subtract the padding
                 - $divs;                 # Subtract dividers

    # Make sure we do not spill off the screen
    resize($max_size, \@show, \@lengths) if sum(@lengths) > $max_size;

    # Put together borders and row template
    my $border   = join '-', '+', map { '-' x $lengths[$_], "+" } @show;
    my $row_tmpl = join ' ', '|', map { "\%s |" } @show;

    for my $row ($header ? ($header) : (), @$rows) {
        for my $i (@show) {
            $row->[$i]->break($lengths[$i]);
        }
    }

    my @new_rows;
    my $span = 0;
    while (@$rows) {
        my @new;
        my $row = $rows->[0];
        my $found = 0;
        $span++;

        for my $i (@show) {
            my $item = $row->[$i];
            my $part = $item->next;

            if (defined($part)) {
                $found++;
                push @new => $part;
            }
            else {
                push @new => ' ' x $lengths[$i];
            }
        }

        if ($found || $span > 2) {
            push @new_rows => \@new;
        }

        unless ($found) {
            shift @$rows;
            $span = 0;
        }
    }

    # Remove trailing row padding
    pop @new_rows if @new_rows && !grep { m/\S/ } @{$new_rows[-1]};

    return (
        $uniwarn && !$INC{'Unicode/GCString.pm'} ? (
            "Unicode::GCString is not installed, table may not display all unicode characters properly",
        ) : (),

        $header ? (
            $border,
            sprintf($row_tmpl, map { $_->next } @$header[@show]),
        ) : (),

        $border,

        (map {sprintf($row_tmpl, @{$_})} @new_rows),

        $border,
    );
}

1;

__END__


=pod

=encoding UTF-8

=head1 NAME

Test2::Util::Table - Format a header and rows into a table

=head1 DESCRIPTION

This is used by some failing tests to provide diagnostics about what has gone
wrong. This module is able to generic format rows of data into tables.

=head1 SYNOPSIS

    use Test2::Util::Table qw/table/;

    my @table = table(
        max_width => 80,
        collapse => 1, # Do not show empty columns
        header => [ 'name', 'age', 'hair color' ],
        rows => [
            [ 'Fred Flinstone',  2000000, 'black' ],
            [ 'Wilma Flinstone', 1999995, 'red' ],
            ...,
        ],
    );

    # The @table array contains each line of the table, no newlines added.
    say $_ for @table;

This prints a table like this:

    +-----------------+---------+------------+
    | name            | age     | hair color |
    +-----------------+---------+------------+
    | Fred Flinstone  | 2000000 | black      |
    | Wilma Flinstone | 1999995 | red        |
    | ...             | ...     | ...        |
    +-----------------+---------+------------+

=head1 EXPORTS

=head2 @rows = table(...)

The function returns a list of lines, lines do not have the newline C<\n>
character appended.

Options:

=over 4

=item header => [ ... ]

If you want a header specify it here. This takes an arrayref with each columns
heading.

=item rows => [ [...], [...], ... ]

This should be an arrayref containing an arrayref per row.

=item collapse => $bool

Use this if you want to hide empty columns, that is any column that has no data
in any row. Having a header for the column will not effect collapse.

=item max_width => $num

Set the maximum width of the table, the table may not be this big, but it will
be no bigger. If none is specified it will attempt to fidn the width of your
terminal and use that, otherwise it falls back to C<80>.

=item sanitize => $bool

This will sanitize all the data in the table such that newlines, control
characters, and all whitespace except for ASCII 20 C<' '> are replaced with
escape sequences. This prevents newlines, tabs, and similar whitespace from
disrupting the table.

B<Note:> newlines are marked as '\n', but a newline is also inserted into the
data so that it typically displays in a way that is useful to humans.

Example:

    my $field = "foo\nbar\nbaz\n";

    print join "\n" => table(
        sanitize => 1,
        rows => [
            [$field,      'col2'     ],
            ['row2 col1', 'row2 col2']
        ]
    );

Prints:

    +-----------------+-----------+
    | foo\n           | col2      |
    | bar\n           |           |
    | baz\n           |           |
    |                 |           |
    | row2 col1       | row2 col2 |
    +-----------------+-----------+

So it marks the newlines by inserting the escape sequence, but it also shows
the data across as many lines as it would normally display.

=item mark_tail => $bool

This will replace the last whitespace character of any trailing whitespace with
its escape sequence. This makes it easier to notice trailing whitespace when
comparing values.

=back

=head2 my $cols = term_size()

Attempts to find the width in columns (characters) of the current terminal.
Returns 80 as a safe bet if it cannot find it another way. This is most
accurate if L<Term::ReadKey> is installed.

=head1 NOTE ON UNICODE/WIDE CHARATERS

Some unicode characters, such as C<婧> (C<U+5A67>) are wider than others. These
will render just fine if you C<use utf8;> as necessary, and
L<Unicode::GCString> is installed, however if the module is not installed there
will be anomolies in the table:

    +-----+-----+---+
    | a   | b   | c |
    +-----+-----+---+
    | 婧 | x   | y |
    | x   | y   | z |
    | x   | 婧 | z |
    +-----+-----+---+

=head1 SOURCE

The source code repository for Test2-Suite can be found at
F<http://github.com/Test-More/Test2-Suite/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
