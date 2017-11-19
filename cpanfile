requires "perl" => "5.008001";

on 'test' => sub {
  requires "Test2::Tools::Tiny" => "1.302111";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Test::Pod" => "1.41";
  requires "Test::Spelling" => "0.12";
};
