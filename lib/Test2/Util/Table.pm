package Test2::Util::Table;
use strict;
use warnings;

our $VERSION = '0.000063';

use Test2::Util::Table::Cell();

use Test2::Util::Term qw/term_size uni_length USE_GCS/;
use Scalar::Util qw/blessed/;
use List::Util qw/max sum/;
use Carp qw/croak carp/;

use Importer Importer => 'import';
our @EXPORT_OK  = qw/table/;
our %EXPORT_GEN = (
    '&term_size' => sub {
        require Carp;
        Carp::cluck "term_size should be imported from Test2::Util::Term, not " . __PACKAGE__;
        Test2::Util::Term->can('term_size');
    },
);

use Test2::Util::HashBase qw/rows _columns collapse max_width mark_tail sanitize show_header auto_columns no_collapse header/;

sub BORDER_SIZE()   { 4 }    # '| ' and ' |' borders
sub DIV_SIZE()      { 3 }    # ' | ' column delimiter
sub PAD_SIZE()      { 4 }    # Extra arbitrary padding
sub CELL_PAD_SIZE() { 2 }    # space on either side of the |

sub init {
    my $self = shift;

    croak "You cannot have a table with no rows"
        unless $self->{+ROWS} && @{$self->{+ROWS}};

    $self->{+MAX_WIDTH}   ||= term_size();
    $self->{+NO_COLLAPSE} ||= {};
    if (ref($self->{+NO_COLLAPSE}) eq 'ARRAY') {
        $self->{+NO_COLLAPSE} = {map { ($_ => 1) } @{$self->{+NO_COLLAPSE}}};
    }

    $self->{+COLLAPSE}  = 1 unless defined $self->{+COLLAPSE};
    $self->{+SANITIZE}  = 1 unless defined $self->{+SANITIZE};
    $self->{+MARK_TAIL} = 1 unless defined $self->{+MARK_TAIL};

    if($self->{+HEADER}) {
        $self->{+SHOW_HEADER}  = 1 unless defined $self->{+SHOW_HEADER};
    }
    else {
        $self->{+HEADER}       = [];
        $self->{+AUTO_COLUMNS} = 1;
        $self->{+SHOW_HEADER}  = 0;
    }
}

sub columns {
    my $self = shift;

    $self->regen_columns unless $self->{+_COLUMNS};

    return $self->{+_COLUMNS};
}

sub regen_columns {
    my $self = shift;

    my $has_header = $self->{+SHOW_HEADER} && @{$self->{+HEADER}};
    my %new_row = (width => 0, count => $has_header ? -1 : 0);

    my $cols = [map { {%new_row} } @{$self->{+HEADER}}];
    my @rows = @{$self->{+ROWS}};

    for my $row ($has_header ? ($self->{+HEADER}, @rows) : (@rows)) {
        for my $ci (0 .. (@$row - 1)) {
            $cols->[$ci] ||= {%new_row} if $self->{+AUTO_COLUMNS};
            my $c = $cols->[$ci] or next;
            $c->{idx} ||= $ci;
            $c->{rows} ||= [];

            my $r = $row->[$ci];
            $r = Test2::Util::Table::Cell->new(value => $r)
                unless blessed($r)
                && $r->isa('Test2::Util::Table::Cell');

            $r->sanitize  if $self->{+SANITIZE};
            $r->mark_tail if $self->{+MARK_TAIL};

            my $rs = $r->width;
            $c->{width} = $rs if $rs > $c->{width};
            $c->{count}++ if $rs;

            push @{$c->{rows}} => $r;
        }
    }

    # Remove any empty columns we can
    @$cols = grep {$_->{count} > 0 || $self->{+NO_COLLAPSE}->{$_->{idx}}} @$cols
        if $self->{+COLLAPSE};

    my $current = sum(map {$_->{width}} @$cols);
    my $border = sum(BORDER_SIZE, PAD_SIZE, DIV_SIZE * @$cols);
    my $total = $current + $border;

    if ($total > $self->{+MAX_WIDTH}) {
        my $fair = ($self->{+MAX_WIDTH} - $border) / @$cols;
        my $under = 0;
        my @fix;
        for my $c (@$cols) {
            if ($c->{width} > $fair) {
                push @fix => $c;
            }
            else {
                $under += $c->{width};
            }
        }

        # Recalculate fairness
        $fair = int(($self->{+MAX_WIDTH} - $border - $under) / @fix);

        # Adjust over-long columns
        $_->{width} = $fair for @fix;
    }

    $self->{+_COLUMNS} = $cols;
}

sub render {
    my $self = shift;

    my $cols = $self->columns;
    my $width = sum(BORDER_SIZE, PAD_SIZE, DIV_SIZE * @$cols, map { $_->{width} } @$cols);

    #<<< NO-TIDY
    my $border   = '+' . join('+', map { '-' x ($_->{width}  + CELL_PAD_SIZE) }      @$cols) . '+';
    my $template = '|' . join('|', map { my $w = $_->{width} + CELL_PAD_SIZE; '%s' } @$cols) . '|';
    my $spacer   = '|' . join('|', map { ' ' x ($_->{width}  + CELL_PAD_SIZE) }      @$cols) . '|';
    #>>>

    my @out = ($border);
    my ($row, $split, $found) = (0, 0, 0);
    while(1) {
        my @row;

        for my $col (@$cols) {
            my $r = $col->{rows}->[$row];
            unless($r) {
                push @row => '';
                next;
            }

            my $lw = $r->border_left_width;
            my $rw = $r->border_right_width;
            my $vw = $col->{width} - $lw - $rw;
            my $v = $r->break->next($vw);

            if (defined $v) {
                $found++;
                my $bcolor = $r->border_color || '';
                my $vcolor = $r->value_color  || '';
                my $reset  = $r->reset_color  || '';

                if (my $need = $vw - uni_length($v)) {
                    $v .= ' ' x $need;
                }

                my $rt = "${reset}${bcolor}\%s${reset} ${vcolor}\%s${reset} ${bcolor}\%s${reset}";
                push @row => sprintf($rt, $r->border_left || '', $v, $r->border_right || '');
            }
            else {
                push @row => ' ' x ($col->{width} + 2);
            }
        }

        if (!grep {$_ && m/\S/} @row) {
            last unless $found;

            push @out => $border if $row == 0 && $self->{+SHOW_HEADER} && @{$self->{+HEADER}};
            push @out => $spacer if $split > 1;

            $row++;
            $split = 0;
            $found = 0;

            next;
        }

        if ($split == 1 && @out > 1 && $out[-2] ne $border && $out[-2] ne $spacer) {
            my $last = pop @out;
            push @out => ($spacer, $last);
        }

        push @out => sprintf($template, @row);
        $split++;
    }

    pop @out while @out && $out[-1] eq $spacer;

    unless (USE_GCS) {
        for my $row (@out) {
            next unless $row =~ m/[^\x00-\x7F]/;
            unshift @out => "Unicode::GCString is not installed, table may not display all unicode characters properly";
            last;
        }
    }

    return (@out, $border);
}

sub display {
    my $self = shift;
    my ($fh) = @_;

    my @parts = map "$_\n", $self->render;

    print $fh @parts if $fh;
    print @parts;
}

sub table {
    my %params = @_;

    $params{collapse}    ||= 0;
    $params{sanitize}    ||= 0;
    $params{mark_tail}   ||= 0;
    $params{show_header} ||= 0 unless $params{header} && @{$params{header}};

    __PACKAGE__->new(%params)->render;
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
be no bigger. If none is specified it will attempt to find the width of your
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

=head1 NOTE ON UNICODE/WIDE CHARACTERS

Some unicode characters, such as C<婧> (C<U+5A67>) are wider than others. These
will render just fine if you C<use utf8;> as necessary, and
L<Unicode::GCString> is installed, however if the module is not installed there
will be anomalies in the table:

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
