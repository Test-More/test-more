use Test::Stream -Default => (
    qw/DeepCheck LoadPlugin/
);

imported qw{
    is_deeply
    mostly_like
};

not_imported qw{
    match check
    hash array object meta
    item field call prop
    end_items filter_items
    T F D
};

load_plugin DeepCheck => ['-all'];

imported qw{
    is_deeply
    mostly_like

    match check
    hash array object meta
    item field call prop
    end_items filter_items
    T F D
};

done_testing;
