package Test::Builder2::Types;

use Test::Builder2::Mouse::Util qw(load_class);
use Test::Builder2::Mouse::Util::TypeConstraints;

subtype 'Test::Builder2::Positive_Int' => (
    as 'Int',
    where { $_ >= 0 },
);


subtype 'Test::Builder2::LoadableClass', as 'ClassName';
coerce 'Test::Builder2::LoadableClass', from 'Str', via { load_class($_); $_ };


no Test::Builder2::Mouse::Util::TypeConstraints;

1;
