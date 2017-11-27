requires "File::Spec" => "0";
requires "File::Temp" => "0";
requires "Scalar::Util" => "1.13";
requires "Storable" => "0";
requires "perl" => "5.006002";
requires "utf8" => "0";

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "IPC::Open3" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Spelling" => "0.12";
};
