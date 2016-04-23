use warnings;
use strict;

use Config;
use IPC::Open2;
use Test::More;



###
### Initial setup for main test and the persistence worker
###
if (! $ENV{IN_PERSISTENT_ENV_TEST}) {
  $ENV{PERL5LIB} = join ($Config::Config{path_sep}, @INC);
  diag "Testing on perl $] with SpeedyCGI from git://github.com/dbsrgits/cgi-speedycgi.git on Test::More " . Test::More->VERSION;
}
else {
  my $TB = Test::More->builder;

  # without this explicit close the output never makes it out of SCGI
  # and won't be captured by IPC::O2 below
  close ($TB->$_) for qw(output failure_output todo_output);

  # newer TB does not auto-reopen handles, so do it regardless
  open ($TB->output, '>&', *STDOUT);
  open ($TB->todo_output, '>&', *STDOUT);
  open ($TB->failure_output, '>&', *STDERR);

  # so numbers match and done_testing can work on every persistent pass
  $TB->reset;
}



###
### Actual tests (one pass, one TODO)
###
ok 1, "$$ runs";

{
  local $TODO = "little ponies aren't real";
  ok( my $little_pony, "MY LITTLE PONY IS OK!" );
}



###
### Persistence self-re-exec
###
unless( $ENV{IN_PERSISTENT_ENV_TEST}++ ) {

  my $persistence_tests = {
#    'CGI::SpeedyCGI' => {
#      cmd => [qw( speedy -- -t1 ), __FILE__],
#    },
    'Data::Dumper' => {
        cmd => [$^X, __FILE__],
    },
  };

  for my $type (keys %$persistence_tests) { SKIP: {
    skip "$type module not found", 1
      unless (eval "require $type");

    my @cmd = @{$persistence_tests->{$type}{cmd}};

    for (1,2,3) {
      note ("Starting run in persistent env ($type pass $_)");
      IPC::Open2::open2(my $stdout, undef, @cmd);

      my @stdout_lines;
      while (my $ln = <$stdout>) {
        next if $ln =~ /^\s*$/;
        push @stdout_lines, "   $ln";
        last if $ln =~ /^\d+\.\.\d+$/;  # this is persistence, we need to detect "end-of-test" on our end
      }

      print $_ for @stdout_lines;
      close $stdout;

      wait;

      ok (!$?, "Run in persistent env ($type pass $_): exit $?");
      ok (scalar @stdout_lines, "Run in persistent env ($type pass $_): got output");
    }

  } }
}


###
### End of test
###
done_testing;
