package TB2::AssertRecord;

use TB2::Mouse;

use Carp;

our $VERSION = '1.005000_005';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)


=head1 NAME

TB2::AssertRecord - Record an assert happening

=head1 SYNOPSIS

    use TB2::AssertRecord;

    my $record = TB2::AssertRecord->new;
    my $record = TB2::AssertRecord->new_from_caller($level);

    # All the stuff from caller
    my $package  = $record->package;
    my $filename = $record->filename;
    my $line     = $record->line;


=head1 DESCRIPTION

Records where an assert was called.

Useful for diagnostics and stack traces.

=head1 Constructors

=head2 new

    my $record = TB2::AssertRecord->new({
        package    => $package,
        line       => $line,
        filename   => $filename,
        subroutine => $subroutine
    });

The normal Mouse constructor.  You must supply all the caller
information manually.

You should use C<new_from_caller>.

=head2 new_from_caller

    my $record = TB2::AssertRecord->new_from_caller($level);

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


=head2 new_from_guess

    my $record = TB2::AssertRecord->new_from_guess;
    my $record = TB2::AssertRecord->new_from_guess(@ignore_packages);

Constructs an AssertRecord for you by looking up the call stack until
it is out of the calling class.

If @ignore_packages is given, those are also to be ignored when looking
up the stack.

=cut

sub new_from_guess {
    my $class = shift;
    my %ignore = map { $_ => 1 } @_;

    $ignore{ caller() } = 1;

    my @last_caller;
    my $height = 0;
    while(1) {
        my @caller = caller($height++);

        last if !@caller;               # walked off the stack

        @last_caller = @caller;

        last unless $ignore{$caller[0]};
    } 

    return $class->new(
        package    => $last_caller[0],
        filename   => $last_caller[1],
        line       => $last_caller[2],
        subroutine => $last_caller[3],
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

no TB2::Mouse;

1;
