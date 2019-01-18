requires "B" => "0";
requires "Carp" => "0";
requires "Data::Dumper" => "0";
requires "Exporter" => "0";
requires "Importer" => "0.024";
requires "Module::Pluggable" => "2.7";
requires "Scalar::Util" => "0";
requires "Scope::Guard" => "0";
requires "Sub::Info" => "0.002";
requires "Term::Table" => "0.013";
requires "Test2::API" => "1.302158";
requires "Time::HiRes" => "0";
requires "overload" => "0";
requires "perl" => "5.008001";
requires "utf8" => "0";
suggests "Sub::Name" => "0.11";
suggests "Term::ReadKey" => "0";
suggests "Term::Size::Any" => "0";
suggests "Unicode::GCString" => "0";
suggests "Unicode::LineBreak" => "0";

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Test::Pod" => "1.41";
  requires "Test::Spelling" => "0.12";
};
