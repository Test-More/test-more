package Test::Builder::Formatter::TAP;
use strict;
use warnings;

use Test::Builder::Threads;
use Test::Builder::Util qw/accessors transform try protect/;

use base 'Test::Builder::Formatter';

accessors qw/No_Header No_Diag Depth Use_Numbers _the_plan/;
transform output         => ('Out_FH',  '_new_fh');
transform failure_output => ('Fail_FH', '_new_fh');
transform todo_output    => ('Todo_FH', '_new_fh');

sub init {
    my $self = shift;
    $self->reset_outputs;
    $self->use_numbers(1);

    $self->{number} = 0;
    share( $self->{number} );

    $self->{ok_lock} = 1;
    share( $self->{ok_lock} );
}

for my $handler (qw/bail nest/) {
    my $sub = sub {
        my $self = shift;
        my ($item) = @_;
        $self->_print($item->indent || "", $item->to_tap);
    };
    no strict 'refs';
    *$handler = $sub;
}

sub child {
    my $self = shift;
    my ($item) = @_;

    return unless $item->action eq 'push' && $item->is_subtest;

    my $name = $item->name;
    $self->_print_to_fh( $self->output, $item->indent || "", "# Subtest: $name\n" );
}

sub finish {
    my $self = shift;
    my ($item) = @_;

    return if $self->no_header;
    return unless $item->tests_run;

    my $plan = $self->_the_plan;
    return unless $plan;

    if ($plan) {
        return unless $plan->directive;
        return unless $plan->directive eq 'NO_PLAN';
    }

    my $total = $item->tests_run;
    $self->_print($item->indent || '', "1..$total\n");
}

sub plan {
    my $self = shift;
    my ($item) = @_;

    $self->_the_plan($item);

    return if $self->no_header;

    return if $item->directive && $item->directive eq 'NO_PLAN';

    my $out = $item->to_tap;
    return unless $out;

    $self->_print($item->indent || "", $out);
}

sub ok {
    my $self = shift;
    my ($item) = @_;
    lock $self->{ok_lock};
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
        lock $self->{number};
        $self->{number} += $num;
    }
    return $self->{number};
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

    $msg =~ s/^/$indent/mg;

    return print $fh $msg;
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

    try {
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
        open $fh, ">>", $file_or_fh
          or $self->croak("Can't open scalar ref $file_or_fh: $!");
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

    my $out;
    protect {
        $out = eval { $maybe_fh->isa("IO::Handle") }
            || eval { tied($maybe_fh)->can('TIEHANDLE') };
    };

    return $out;
}

sub reset {
    my $self = shift;
    $self->reset_outputs;
    $self->no_header(0);
    $self->use_numbers(1);
    $self->{number} = 0;
    share( $self->{number} );
}

1;

__END__

=head1 NAME

Test::Builder::Formatter::TAP - TAP formatter.

=head1 TEST COMPONENT MAP

  [Test Script] > [Test Tool] > [Test::Builder] > [Test::Bulder::Stream] > [Result Formatter]
                                                                                   ^
                                                                             You are here

A test script uses a test tool such as L<Test::More>, which uses Test::Builder
to produce results. The results are sent to L<Test::Builder::Stream> which then
forwards them on to one or more formatters. The default formatter is
L<Test::Builder::Fromatter::TAP> which produces TAP output.

=head1 DESCRIPTION

This module is responsible for taking results from the stream and outputting
TAP. You probably should not directly interact with this.

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 COPYRIGHT

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>
