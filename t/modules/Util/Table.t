use Test2::Bundle::Extended;
use Test2::Util::Table qw/table term_size/;

imported_ok qw/table term_size/;

{
    local $ENV{T2_TERM_SIZE} = 42;
    is(term_size, 42, "used env var");
    local $ENV{T2_TERM_SIZE} = 1000;
    is(term_size, 1000, "used env var again");
}

if ($INC{'Term/ReadKey.pm'}) {
    local $ENV{'T2_TERM_SIZE'};
    my $size;
    my $ok = eval {
        local $SIG{__WARN__} = sub { 1 };
        ($size) = Term::ReadKey::GetTerminalSize(*STDOUT);
        1;
    };

    $size = 80 if $size < 80;
    is(term_size(), $size, "Got size from Term::ReadKey") if $ok && $size;

    no warnings 'redefine';
    local *Term::ReadKey::GetTerminalSize = sub { 0 };
    is(term_size(), 80, "use default of 80 if Term::ReadKey fails");
}
else {
    local %ENV = %ENV;
    delete $ENV{'T2_TERM_SIZE'};
    is(term_size(), 80, "Default to 80");
}


my $unsanitary = <<EOT;
This string
has vertical space
including          　‌﻿\N{U+000B}unicode stuff
and some non-whitespace ones: 婧 ʶ ๖
EOT
my $sanitary = 'This string\nhas vertical space\nincluding\N{U+A0}\N{U+1680}\N{U+2000}\N{U+2001}\N{U+2002}\N{U+2003}\N{U+2004}\N{U+2008}\N{U+2028}\N{U+2029}\N{U+3000}\N{U+200C}\N{U+FEFF}\N{U+B}unicode stuff\nand some non-whitespace ones: 婧 ʶ ๖\n';

subtest sanitization => sub {
    local *show_char = Test2::Util::Table->can('show_char');
    local *sanitize  = Test2::Util::Table->can('sanitize');

    # Common control characters
    is(show_char("\a"), '\a', "translated bell");
    is(show_char("\b"), '\b', "translated backspace");
    is(show_char("\e"), '\e', "translated escape");
    is(show_char("\f"), '\f', "translated formfeed");
    is(show_char("\n"), '\n', "translated newline");
    is(show_char("\r"), '\r', "translated return");
    is(show_char("\t"), '\t', "translated tab");
    is(show_char(" "),  ' ', "plain space is not translated");

    # unicodes
    is(show_char("婧"), '\N{U+5A67}', "translated unicode 婧 (U+5A67)");
    is(show_char("ʶ"),  '\N{U+2B6}',  "translated unicode ʶ (U+2B6)");
    is(show_char("߃"),  '\N{U+7C3}',  "translated unicode ߃ (U+7C3)");
    is(show_char("๖"),  '\N{U+E56}',  "translated unicode ๖ (U+E56)");

    sanitize(my $sanitized = "$unsanitary");

    is($sanitized, $sanitary, "Sanitized string");
};

subtest unicode_display_width => sub {
    my $wide = "foo bar baz 婧";

    my $have_gcstring = eval { require Unicode::GCString; 1 };

    subtest no_unicode_linebreak => sub {
        my @table;
        {
            local %INC = %INC;
            delete $INC{'Unicode/GCString.pm'};
            @table = table('header' => [ 'a', 'b'], 'rows'   => [[ '婧', '߃' ]]);
        }

        like(
            \@table,
            ["Unicode::GCString is not installed, table may not display all unicode characters properly"],
            "got unicode note"
        );
    };

    return unless $have_gcstring;
    subtest with_unicode_linebreak => sub {
        my @table = table(
            'header' => [ 'a', 'b'],
            'rows'   => [[ 'a婧b', '߃' ]],
            'max_width' => 80,
        );
        is(
            \@table,
            [
                '+------+---+',
                '| a    | b |',
                '+------+---+',
                '| a婧b | ߃ |',
                '+------+---+',
            ],
            "Support for unicode characters that use multiple columns"
        );
    };
};

subtest width => sub {
    my @table = table(
        max_width => 40,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbb ccccccccccccccccccccccc ddddddddddddddddddddddddddddd/ ],
            [ qw/AAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBBBBBBB CCCCCCCCCCCCCCCCCCCCCCC DDDDDDDDDDDDDDDDDDDDDDDDDDDDD/ ],
        ],
    );

    is(length($table[0]), validator('<=', '40', sub { my %p = @_; $p{got} <= $p{name} }), "width of table");

    is(
        \@table,
        [
            '+-------+-------+-------+-------+',
            '| a     | b     | c     | d     |',
            '+-------+-------+-------+-------+',
            '| aaaaa | bbbbb | ccccc | ddddd |',
            '| aaaaa | bbbbb | ccccc | ddddd |',
            '| aaaaa | bbbbb | ccccc | ddddd |',
            '| aaaaa | bbbbb | ccccc | ddddd |',
            '| aaaaa | b     | ccc   | ddddd |',
            '| a     |       |       | dddd  |',
            '|       |       |       |       |',
            '| AAAAA | BBBBB | CCCCC | DDDDD |',
            '| AAAAA | BBBBB | CCCCC | DDDDD |',
            '| AAAAA | BBBBB | CCCCC | DDDDD |',
            '| AAAAA | BBBBB | CCCCC | DDDDD |',
            '| AAAAA | B     | CCC   | DDDDD |',
            '| A     |       |       | DDDD  |',
            '+-------+-------+-------+-------+',
        ],
        "Basic table, small width"
    );

    @table = table(
        max_width => 60,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaaaaaaaaaaaaaaaaaaaaaaaa bbbbbbbbbbbbbbbbbbbbb ccccccccccccccccccccccc ddddddddddddddddddddddddddddd/ ],
            [ qw/AAAAAAAAAAAAAAAAAAAAAAAAAA BBBBBBBBBBBBBBBBBBBBB CCCCCCCCCCCCCCCCCCCCCCC DDDDDDDDDDDDDDDDDDDDDDDDDDDDD/ ],
        ],
    );

    is(length($table[0]), validator('<=', '60', sub { my %p = @_; $p{got} <= $p{name} }), "width of table");

    is(
        \@table,
        [
            '+------------+------------+------------+------------+',
            '| a          | b          | c          | d          |',
            '+------------+------------+------------+------------+',
            '| aaaaaaaaaa | bbbbbbbbbb | cccccccccc | dddddddddd |',
            '| aaaaaaaaaa | bbbbbbbbbb | cccccccccc | dddddddddd |',
            '| aaaaaa     | b          | ccc        | ddddddddd  |',
            '|            |            |            |            |',
            '| AAAAAAAAAA | BBBBBBBBBB | CCCCCCCCCC | DDDDDDDDDD |',
            '| AAAAAAAAAA | BBBBBBBBBB | CCCCCCCCCC | DDDDDDDDDD |',
            '| AAAAAA     | B          | CCC        | DDDDDDDDD  |',
            '+------------+------------+------------+------------+',
        ],
        "Basic table, bigger width"
    );

    @table = table(
        max_width => 60,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaa bbbb cccc dddd/ ],
            [ qw/AAAA BBBB CCCC DDDD/ ],
        ],
    );

    is(length($table[0]), validator('<=', '60', sub { my %p = @_; $p{got} <= $p{name} }), "width of table");

    is(
        \@table,
        [
            '+------+------+------+------+',
            '| a    | b    | c    | d    |',
            '+------+------+------+------+',
            '| aaaa | bbbb | cccc | dddd |',
            '| AAAA | BBBB | CCCC | DDDD |',
            '+------+------+------+------+',
        ],
        "Short table, well under minimum",
    );
};

subtest collapse => sub {
    my @table = table(
        max_width => 60,
        collapse => 1,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaa bbbb/, undef, qw/dddd/ ],
            [ qw/AAAA BBBB/, '', qw/DDDD/ ],
        ],
    );

    is(
        \@table,
        [
            '+------+------+------+',
            '| a    | b    | d    |',
            '+------+------+------+',
            '| aaaa | bbbb | dddd |',
            '| AAAA | BBBB | DDDD |',
            '+------+------+------+',
        ],
        "Table collapsed",
    );

    @table = table(
        max_width => 60,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaa bbbb/, undef, qw/dddd/ ],
            [ qw/AAAA BBBB/, '', qw/DDDD/ ],
        ],
    );

    is(
        \@table,
        [
            '+------+------+---+------+',
            '| a    | b    | c | d    |',
            '+------+------+---+------+',
            '| aaaa | bbbb |   | dddd |',
            '| AAAA | BBBB |   | DDDD |',
            '+------+------+---+------+',
        ],
        "Table not collapsed",
    );

    @table = table(
        max_width => 60,
        collapse => 1,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaa bbbb/, undef, qw/dddd/ ],
            [ qw/AAAA BBBB/, 0, qw/DDDD/ ],
        ],
    );

    is(
        \@table,
        [
            '+------+------+---+------+',
            '| a    | b    | c | d    |',
            '+------+------+---+------+',
            '| aaaa | bbbb |   | dddd |',
            '| AAAA | BBBB | 0 | DDDD |',
            '+------+------+---+------+',
        ],
        "'0' value does not cause collapse",
    );

};

subtest header => sub {
    my @table = table(
        max_width => 60,
        header => [ 'a', 'b', 'c', 'd' ],
        rows => [
            [ qw/aaaa bbbb cccc dddd/ ],
            [ qw/AAAA BBBB CCCC DDDD/ ],
        ],
    );

    is(
        \@table,
        [
            '+------+------+------+------+',
            '| a    | b    | c    | d    |',
            '+------+------+------+------+',
            '| aaaa | bbbb | cccc | dddd |',
            '| AAAA | BBBB | CCCC | DDDD |',
            '+------+------+------+------+',
        ],
        "Table with header",
    );
};

subtest no_header => sub {
    my @table = table(
        max_width => 60,
        rows => [
            [ qw/aaaa bbbb cccc dddd/ ],
            [ qw/AAAA BBBB CCCC DDDD/ ],
        ],
    );

    is(
        \@table,
        [
            '+------+------+------+------+',
            '| aaaa | bbbb | cccc | dddd |',
            '| AAAA | BBBB | CCCC | DDDD |',
            '+------+------+------+------+',
        ],
        "Table without header",
    );
};

subtest sanitize => sub {
    my @table = table(
        max_width => 60,
        sanitize => 1,
        header => [ 'data1' ],
        rows => [["a\t\n\r\b\a          　‌﻿\N{U+000B}b"]],
    );

    is(
        \@table,
        [
            ( $INC{'Unicode/GCString.pm'}
                ? ()
                : ("Unicode::GCString is not installed, table may not display all unicode characters properly")
            ),
            '+---------------------------------------------------+',
            '| data1                                             |',
            '+---------------------------------------------------+',
            '| a\t\n                                             |',
            '| \r\b\a\N{U+A0}\N{U+1680}\N{U+2000}\N{U+2001}\N{U+ |',
            '| 2002}\N{U+2003}\N{U+2004}\N{U+2008}\N{U+2028}\N{U |',
            '| +2029}\N{U+3000}\N{U+200C}\N{U+FEFF}\N{U+B}b      |',
            '+---------------------------------------------------+',
        ],
        "Sanitized data"
    );
};

subtest mark_tail => sub {
    my @table = table(
        max_width => 60,
        mark_tail => 1,
        header => [ 'data1', 'data2' ],
        rows => [["  abc  def   ", "  abc  def  \t"]],
    );

    is(
        \@table,
        [
            '+----------------------+----------------+',
            '| data1                | data2          |',
            '+----------------------+----------------+',
            '|   abc  def  \N{U+20} |   abc  def  \t |',
            '+----------------------+----------------+',
        ],
        "Sanitized data"
    );

};

done_testing;
