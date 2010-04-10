package Test::Builder2::Types;

use Mouse::Util::TypeConstraints;

subtype 'Test::Builder2::Positive_Int' => (
    as 'Int',
    where { $_ >= 0 },
);

1;

no Mouse::Util::TypeConstraints;
