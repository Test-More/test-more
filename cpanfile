requires "B" => "0";
requires "Carp" => "0";
requires "Importer" => "0.024";
requires "List::Util" => "0";
requires "Scalar::Util" => "0";
requires "Test2" => "1.302032";
requires "overload" => "0";
requires "perl" => "5.008001";
requires "utf8" => "0";

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Test::Pod" => "1.41";
};
