use Test::Stream -V1, -SpecTester;
use utf8;

set_encoding 'utf8';

use Test::Stream::Table::LineBreak;

tests with_unicode_linebreak => sub {
    my $one = Test::Stream::Table::LineBreak->new(string => 'aaaa婧bbbb');
    $one->break(3);
    is(
        [ map { $one->next } 1 .. 5 ],
        [
            'aaa',
            'a婧',
            'bbb',
            'b  ',
            undef
        ],
        "Got all parts"
    );

    $one = Test::Stream::Table::LineBreak->new(string => 'a婧bb');
    $one->break(2);
    is(
        [ map { $one->next } 1 .. 4 ],
        [
            'a ',
            '婧',
            'bb',
            undef
        ],
        "Padded the problem"
    );

} if $INC{'Unicode/LineBreak.pm'};

tests without_unicode_linebreak => sub {
    my @parts;
    {
        local %INC = %INC;
        delete $INC{'Unicode/GCString.pm'};
        my $one = Test::Stream::Table::LineBreak->new(string => 'aaaa婧bbbb');
        $one->break(3);
        @parts = map { $one->next } 1 .. 5;
    }

    todo "Can't handle unicode properly without Unicode::GCString" => sub {
        is(
            \@parts,
            [
                'aaa',
                'a婧',
                'bbb',
                'b  ',
                undef
            ],
            "Got all parts"
        );
    };

    my $one = Test::Stream::Table::LineBreak->new(string => 'aaabbbx');
    $one->break(2);
    is(
        [ map { $one->next } 1 .. 5 ],
        [
            'aa',
            'ab',
            'bb',
            'x ',
            undef
        ],
        "Padded the problem"
    );

};

done_testing;
