package Test::Builder::Formatter::TAP;
use strict;
use warnings;

BEGIN {
    if( $] < 5.008 ) {
        require Test::Builder::IO::Scalar;
    }
}

use parent 'Test::Builder::Formatter';

sub init {
    my $self = shift;
    $self->reset_outputs;
    $self->use_numbers(1);
}

# The default 6 result types all have a to_tap method.
for my $handler (qw/plan bail nest/) {
    my $sub = sub {
        my $self = shift;
        my ($item) = @_;
        $self->_print($item->indent || "", $item->to_tap);
    };
    no strict 'refs';
    *$handler = $sub;
}

sub ok {
     my $self = shift;
     my ($item) = @_;
     $self->_print($item->indent || "", $item->to_tap($self->test_number(1)));
}

sub diag {
    my $self = shift;
    my ($item) = @_;

    return if $self->no_diag;

    # Prevent printing headers when compiling (i.e. -c)
    return if $^C;

    $self->_print_to_fh( $self->_diag_fh($item->in_todo), $item->indent || "", $item->to_tap );
}

sub note {
    my $self = shift;
    my ($item) = @_;

    return if $self->no_diag;

    # Prevent printing headers when compiling (i.e. -c)
    return if $^C;

    $self->_print_to_fh( $self->output, $item->indent || "", $item->to_tap );
}

sub test_number {
    my $self = shift;
    return unless $self->use_numbers;
    if (@_) {
        my ($num) = @_;
        $num ||= 0;
        $self->{number} += $num;
    }
    return $self->{number} || 0;
}

for my $attribute (qw(No_Header No_Diag Depth Use_Numbers)) {
    my $method = lc $attribute;

    my $code = sub {
        my ($self, $no) = @_;
        if( defined $no ) {
            $self->{$attribute} = $no;
        }
        return $self->{$attribute};
    };

    no strict 'refs';    ## no critic
    *$method = $code;
}

sub _diag_fh {
    my $self = shift;
    my ($in_todo) = @_;

    return $in_todo ? $self->todo_output : $self->failure_output;
}

sub _print {
    my $self = shift;
    my ($indent, @msgs) = @_;
    return $self->_print_to_fh( $self->output, $indent, @msgs );
}

sub _print_to_fh {
    my( $self, $fh, $indent, @msgs ) = @_;

    # Prevent printing headers when only compiling.  Mostly for when
    # tests are deparsed with B::Deparse
    return if $^C;

    my $msg = join '', @msgs;

    local( $\, $", $, ) = ( undef, ' ', '' );

    # Escape each line after the first with a # so we don't
    # confuse Test::Harness.
    $msg =~ s{\n(?!\z)}{\n$indent# }sg;

    # Stick a newline on the end if it needs it.
    $msg .= "\n" unless $msg =~ /\n\z/;

    return print $fh $indent, $msg;
}

sub output {
    my( $self, $fh ) = @_;

    if( defined $fh ) {
        $self->{Out_FH} = $self->_new_fh($fh);
    }
    return $self->{Out_FH};
}

sub failure_output {
    my( $self, $fh ) = @_;

    if( defined $fh ) {
        $self->{Fail_FH} = $self->_new_fh($fh);
    }
    return $self->{Fail_FH};
}

sub todo_output {
    my( $self, $fh ) = @_;

    if( defined $fh ) {
        $self->{Todo_FH} = $self->_new_fh($fh);
    }
    return $self->{Todo_FH};
}

my( $Testout, $Testerr );

sub reset_outputs {
    my $self = shift;

    _init_handles();

    $self->output        ($Testout);
    $self->failure_output($Testerr);
    $self->todo_output   ($Testout);
}

sub _init_handles {
    # We dup STDOUT and STDERR so people can change them in their
    # test suites while still getting normal test output.
    open( $Testout, ">&STDOUT" ) or die "Can't dup STDOUT:  $!";
    open( $Testerr, ">&STDERR" ) or die "Can't dup STDERR:  $!";

    _copy_io_layers( \*STDOUT, $Testout );
    _copy_io_layers( \*STDERR, $Testerr );

    # Set everything to unbuffered else plain prints to STDOUT will
    # come out in the wrong order from our own prints.
    _autoflush($Testout);
    _autoflush( \*STDOUT );
    _autoflush($Testerr);
    _autoflush( \*STDERR );

    return;
}

sub _copy_io_layers {
    my($src, $dst) = @_;

    eval {
        local $!;               # eval can mess up $!
        local $@;               # don't set $@ in the test
        local $SIG{__DIE__};    # don't trip an outside DIE handler.

        require PerlIO;
        my @src_layers = PerlIO::get_layers($src);

        _apply_layers($dst, @src_layers) if @src_layers;
    };

    return;
}

sub _apply_layers {
    my ($fh, @layers) = @_;
    my %seen;
    my @unique = grep { $_ ne 'unix' and !$seen{$_}++ } @layers;
    binmode($fh, join(":", "", "raw", @unique));
}

sub _new_fh {
    my $self = shift;
    my($file_or_fh) = shift;

    my $fh;
    if( $self->is_fh($file_or_fh) ) {
        $fh = $file_or_fh;
    }
    elsif( ref $file_or_fh eq 'SCALAR' ) {
        # Scalar refs as filehandles was added in 5.8.
        if( $] >= 5.008 ) {
            open $fh, ">>", $file_or_fh
              or $self->croak("Can't open scalar ref $file_or_fh: $!");
        }
        # Emulate scalar ref filehandles with a tie.
        else {
            $fh = Test::Builder::IO::Scalar->new($file_or_fh)
              or $self->croak("Can't tie scalar ref $file_or_fh");
        }
    }
    else {
        open $fh, ">", $file_or_fh
          or $self->croak("Can't open test output log $file_or_fh: $!");
        _autoflush($fh);
    }

    return $fh;
}

sub _autoflush {
    my($fh) = shift;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;

    return;
}

sub is_fh {
    my $self     = shift;
    my $maybe_fh = shift;
    return 0 unless defined $maybe_fh;

    return 1 if ref $maybe_fh  eq 'GLOB';    # its a glob ref
    return 1 if ref \$maybe_fh eq 'GLOB';    # its a glob

    return eval { $maybe_fh->isa("IO::Handle") } ||
           eval { tied($maybe_fh)->can('TIEHANDLE') };
}

sub reset {
    my $self = shift;
    $self->reset_outputs;
    $self->no_header(0);
    $self->use_numbers(1);
    $self->{number} = 0;
}

1;
