package Test::Builder::Module;

use strict;

use Test::Builder 0.98;

BEGIN {
    require Exporter;
    our @ISA = qw(Exporter);
}

our $VERSION = '1.005000_006';
$VERSION = eval $VERSION;      ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

Test::Builder::Module - Base class for test modules

=head1 SYNOPSIS

  # Emulates Test::Simple
  package Your::Module;

  my $CLASS = __PACKAGE__;

  use base 'Test::Builder::Module';
  @EXPORT = qw(ok);

  sub ok ($;$) {
      my $tb = $CLASS->builder;
      return $tb->ok(@_);
  }
  
  1;


=head1 DESCRIPTION

This is a superclass for Test::Builder-based modules.  It provides a
handful of common functionality and a method of getting at the underlying
Test::Builder object.


=head2 Importing

Test::Builder::Module is a subclass of Exporter which means your
module is also a subclass of Exporter.  @EXPORT, @EXPORT_OK, etc...
all act normally.

A few methods are provided to do the C<< use Your::Module tests => 23 >> part
for you.

=head3 import

Test::Builder::Module provides an import() method which acts in the
same basic way as Test::More's, setting the plan and controlling
exporting of functions and variables.  This allows your module to set
the plan independent of Test::More.

All arguments passed to import() are passed onto 
C<< Your::Module->builder->plan() >> with some exceptions below.

import() also sets the exported_to() attribute of your builder to be
the caller of the import() function.

Additional behaviors can be added to your import() method by overriding
import_extra().

The special keywords are...

=over 4

=item B<import>

C<import> can be passed an array ref of symbols to import, using the
normal L<Exporter> syntax.

    use Your::Module import => [qw(this that)], tests => 23;

Says to import the functions this() and that() as well as set the plan
to be 23 tests.

    use Your::Module import => [qw(!fail)], tests => 23;

Say to export everything normally, except the C<fail> function.


=item B<formatter>

C<formatter> can be used to change the L<TB2::Formatter> used to
output test results.

    use TB2::Formatter::POSIX;
    use Your::Module formatter => TB2::Formatter::POSIX->new;

The test will then use the POSIX formatter rather than the normal TAP
formatter.  Note this effects the whole test, not just the functions
in your module.

See L<Test::Builder/set_formatter> for more details.

=back

=cut

my $special_imports = {
    formatter => sub {
        my $class     = shift;
        my $formatter = shift;

        $class->builder->set_formatter($formatter);

        return $formatter;
    },
};

sub import {
    my($class) = shift;
    my @args = @_;

    # Don't run all this when loading ourself.
    return 1 if $class eq 'Test::Builder::Module';

    my $test = $class->builder;

    my $caller = caller;

    $test->exported_to($caller);

    # Special case for 'use Test::More "no_plan"'
    # Normalize it into 'use Test::More no_plan => 1' so we can hash the
    # args list.
    push @args, 1 if @args == 1 and $args[0] eq 'no_plan';

    # Let a module do whatever extra things it likes
    $class->import_extra( \@args );

    my %args = @args;

    my $imports = delete $args{import};

    for my $key (keys %$special_imports) {
        my $method = $special_imports->{$key};
        $class->$method(delete $args{$key}) if exists $args{$key};
    }

    # We're left with test plan arguments
    $test->plan(%args);

    $class->export_to_level( 1, $class, @$imports );
}


=head3 import_extra

    Your::Module->import_extra(\@import_args);

import_extra() is called by import().  It provides an opportunity for you
to add behaviors to your module based on its import list.

Any extra arguments which shouldn't be passed on to plan() should be 
stripped off by this method.

See Test::More for an example of its use.

B<NOTE> This mechanism is I<VERY ALPHA AND LIKELY TO CHANGE> as it
feels like a bit of an ugly hack in its current form.

=cut

sub import_extra { }

=head2 Builder

Test::Builder::Module provides some methods of getting at the underlying
Test::Builder object.

=head3 builder

  my $builder = Your::Class->builder;

This method returns the Test::Builder object associated with Your::Class.
It is not a constructor so you can call it as often as you like.

This is the preferred way to get the Test::Builder object.  You should
I<not> get it via C<< Test::Builder->new >> as was previously
recommended.

The object returned by builder() may change at runtime so you should
call builder() inside each function rather than store it in a global.

  sub ok {
      my $builder = Your::Class->builder;

      return $builder->ok(@_);
  }


=cut

sub builder {
    return Test::Builder->new;
}

1;
