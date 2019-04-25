use Test::More;
my $guard = bless {};
sub DESTROY { system('false'); }
plan skip_all => 'some requirement is not met';
