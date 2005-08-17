package Test::Builder::Module;

use Test::Builder;

require Exporter;
@ISA = qw(Exporter);

# 5.004's Exporter doesn't have export_to_level.
my $_export_to_level = sub {
      my $pkg = shift;
      my $level = shift;
      (undef) = shift;                  # redundant arg
      my $callpkg = caller($level);
      $pkg->export($callpkg, @_);
};


=head1 NAME

Test::Builder::Module - Base class for test modules

=head1 SYNOPSIS

  # Emulates Test::Simple
  package My::Test::Simple;

  my $CLASS = __PACKAGE__;

  use base 'Test::Builder::Module';
  @EXPORT = qw(ok);

  sub ok ($;$) {
      my $tb = $CLASS->builder;
      return $tb->ok(@_);
  }
  
  1;

=cut


sub import {
    my($class) = shift;

    my $test = $class->builder;

    my $caller = caller;

    $test->exported_to($caller);

    my $idx = 0;
    my @plan;
    my @imports;
    while( $idx <= $#_ ) {
        my $item = $_[$idx];

        if( defined $item and $item eq 'import' ) {
            push @imports, @{$_[$idx+1]};
            $idx++;
        }
        elsif( defined $item and $item eq 'no_diag' ) {
            $test->no_diag(1);
        }
        else {
            push @plan, $item;
        }

        $idx++;
    }

    $test->plan(@plan);

    $class->$_export_to_level(1, $class, @imports);
}


sub builder {
    return Test::Builder->new;
}


1;
