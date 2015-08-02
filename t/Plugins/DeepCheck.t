use Test::Stream -Default => qw/DeepCheck/;

imported(qw{
    strict_compare relaxed_compare
    array hash
    check
    field elem
});

done_testing;
