use strict;
use warnings;
use Test::More;


my $want = 0;
my $got  = 0;

cmp_ok($got, 'eq', $want, "Passes on correct comparison");

# Invalid operator '#eq' should be rejected by the allowlist
my $threw = !eval { cmp_ok($got, '#eq', $want, "You shall not pass!"); 1 };
ok($threw, "Invalid operator throws");
like($@, qr/#eq is not a valid comparison operator in cmp_ok\(\)/, "Error message mentions invalid operator");

done_testing;
