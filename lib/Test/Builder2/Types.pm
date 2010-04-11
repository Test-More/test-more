package Test::Builder2::Types;

require Test::Builder2::Mouse;
use Test::Builder2::Mouse::Util::TypeConstraints;

subtype 'Test::Builder2::Positive_Int' => (
    as 'Int',
    where { $_ >= 0 },
);

1;

no Test::Builder2::Mouse::Util::TypeConstraints;
