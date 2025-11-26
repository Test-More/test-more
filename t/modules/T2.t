use Test2::V1 -Ppi, T2 => {-as => 'MY_T2'};

{
    package BlahBlah;
    use Test2::V1;
    use T2;

    T2()->imported_ok('T2');
}

not_imported_ok('T2');

T2->ok(1, "Pass when calling on the 'T2' package");
'T2'->ok(1, "Pass when calling on the 'T2' package string");

my @foo = (1, 2, 3);
T2::is(@foo, 3, "prototype works with :: calling form");

T2->done_testing;
