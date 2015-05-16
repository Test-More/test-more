package Test::Stream::TAP;
use strict;
use warnings;

use Test::Stream::Util qw/protect/;

use Test::Stream::HashBase(
    accessors => [qw/no_numbers no_header no_diag handles _encoding/],
);

sub OUT_STD()  { 0 }
sub OUT_ERR()  { 1 }
sub OUT_TODO() { 2 }

use Test::Stream::Exporter;
exports qw/OUT_STD OUT_ERR OUT_TODO/;
no Test::Stream::Exporter;

sub init {
    my $self = shift;

    $self->{+HANDLES} ||= $self->_open_handles;
    if(my $enc = delete $self->{encoding}) {
        $self->encoding($enc);
    }
}

sub encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;
        my $handles = $self->{+HANDLES};
        binmode($_, ":encoding($enc)") for @$handles;
        $self->{+_ENCODING} = $enc;
    }

    return $self->{+_ENCODING};
}

sub write {
    my ($self, $e, $num) = @_;

    return if $^C;
    return if $self->{+NO_DIAG}   && $e->isa('Test::Stream::Event::Diag');
    return if $self->{+NO_HEADER} && $e->isa('Test::Stream::Event::Plan');

    return unless $e->can('to_tap');

    $num = undef if $self->{+NO_NUMBERS};

    my $handles = $self->{+HANDLES};
    my $nesting = $e->nested || 0;
    my $indent = '    ' x $nesting;

    local($\, $", $,) = (undef, ' ', '');
    for my $set ($e->to_tap($num)) {
        my ($hid, $msg) = @$set;
        next unless $msg;
        my $io = $handles->[$hid] || next;

        $msg =~ s/^/$indent/mg if $nesting;
        print $io $msg;
    }

}

sub _open_handles {
    my $self = shift;

    open( my $out, ">&STDOUT" ) or die "Can't dup STDOUT:  $!";
    open( my $err, ">&STDERR" ) or die "Can't dup STDERR:  $!";

    _autoflush($out);
    _autoflush($err);

    if (my $encoding = $self->{+_ENCODING}) {
        binmode($out, ":encoding($encoding)");
        binmode($err, ":encoding($encoding)");
    }

    return [$out, $err, $out];
}

sub _copy_io_layers {
    my($src, $dst) = @_;

    protect {
        require PerlIO;
        my @src_layers = PerlIO::get_layers($src);
        _apply_layers($dst, @src_layers) if @src_layers;
    };

    return;
}

sub _autoflush {
    my($fh) = pop;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::TAP - Standard TAP formatter

=head1 EXPERIMENTAL CODE WARNING

B<This is an experimental release!> Test-Stream, and all its components are
still in an experimental phase. This dist has been released to cpan in order to
allow testers and early adopters the chance to write experimental new tools
with it, or to add experimental support for it into old tools.

B<PLEASE DO NOT COMPLETELY CONVERT OLD TOOLS YET>. This experimental release is
very likely to see a lot of code churn. API's may break at any time.
Test-Stream should NOT be depended on by any toolchain level tools until the
experimental phase is over.

=head1 DESCRIPTION

This is what takes events and turns them into TAP.

=head1 SYNOPSIS

    use Test::Stream::TAP;
    my $tap = Test::Stream::TAP->new();

    # Switch to utf8
    $tap->encoding('utf8');

    $tap->write($event, $number); # Output an event

=head1 EXPORTS

=over 4

=item OUT_STD

=item OUT_ERR

=item OUT_TODO

These are constants to identify filehandles. These constants are used by events
to direct text to the correct filehandle.

=back

=head1 METHODS

=over 4

=item $bool = $tap->no_numbers

=item $tap->set_no_numbers($bool)

Use to turn numbers on and off.

=item $bool = $tap->no_header($bool)

=item $tap->set_no_header($bool)

When true, the plan will not be rendered.

=item $bool = $tap->no_diag

=item $tap->set_no_diag($bool)

When true, diagnostics will not be rendered.

=item $arrayref = $tap->handles

=item $tap->set_handles(\@handles);

Can be used to get/set the filehandles. Indexes are identified by the
C<OUT_STD, OUT_ERR, OUT_TODO> constants.

=item $encoding = $tap->encoding

=item $tap->encoding($encoding)

Get or set the encoding. By default no encoding is set, the original settings
of STDOUT and STDERR are used.

This directly modifies the stored filehandles, it does not create new ones.

=item $tap->write($e, $num)

Write an event to the console.

=back

=head1 SOURCE

The source code repository for Test::Stream can be found at
F<http://github.com/Test-More/Test-Stream/>.

=head1 MAINTAINERS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Kent Fredric E<lt>kentnl@cpan.orgE<gt>

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
