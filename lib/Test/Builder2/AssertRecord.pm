package Test::Builder2::AssertRecord;

use Test::Builder2::Mouse;

use Carp;


=head1 NAME

Test::Builder2::AssertRecord - Record an assert happening

=head1 SYNOPSIS

    use Test::Builder2::AssertRecord;

    my $record = Test::Builder2::AssertRecord->new;
    my $record = Test::Builder2::AssertRecord->new_from_caller($level);

    # All the stuff from caller
    my $package  = $record->package;
    my $filename = $record->filename;
    my $line     = $record->line;


=head1 DESCRIPTION

Records where an assert was called.

Useful for diagnostics and stack traces.

=head1 Constructors

=head2 new

    my $record = Test::Builder2::AssertRecord->new({
        package    => $package,
        line       => $line,
        filename   => $filename,
        subroutine => $subroutine
    });

The normal Mouse constructor.  You must supply all the caller
information manually.

You should use C<new_from_caller>.

=head2 new_from_caller

    my $record = Test::Builder2::AssertRecord->new_from_caller($level);

Constructs an AssertRecord for you by calling caller() at the given
$level above your call in the call stack.

=cut

sub new_from_caller {
    my $class = shift;
    my $level = shift;

    croak "new_from_caller() must be supplied a level" unless defined $level;

    my @caller = caller($level + 1);

    return $class->new(
        package    => $caller[0],
        filename   => $caller[1],
        line       => $caller[2],
        subroutine => $caller[3],
    );
}

=head1 Accessors

These are all read-only and act in the expected manner.

=head2 filename

The filename from which the asset was called.

=head2 line

The line where the assert was called.

=head2 package

The class or package in which the assert was called.

=head2 subroutine

The fully qualified name of the assert being called.

=cut

has filename =>
  is            => 'ro',
  isa           => 'Str',
  required      => 1,
;

has line =>
  is            => 'ro',
  isa           => 'Int',
  required      => 1,
;

has package =>
  is            => 'ro',
  isa           => 'Str',  # ClassName requires the class exist which is too restrictive
  required      => 1,
;

has subroutine =>
  is            => 'ro',
  isa           => 'Str',
;

no Test::Builder2::Mouse;

1;
