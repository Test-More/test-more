package Test::Stream::Block;
use strict;
use warnings;

use Carp qw/confess carp/;
use Scalar::Util qw/blessed reftype/;
use Test::Stream::Util qw/try/;

use Test::Stream::HashBase(
    accessors => [qw/name coderef caller deduced _start_line _end_line/],
);

our %SUB_MAPS;

sub PACKAGE() { 0 };
sub FILE()    { 1 };
sub LINE()    { 2 };
sub SUBNAME() { 3 };

sub init {
    my $self = shift;

    confess "coderef is a mandatory field for " . blessed($self) . " instances"
        unless $self->{+CODEREF};

    confess "caller is a mandatory field for " . blessed($self) . " instances"
        unless $self->{+CALLER};

    confess "coderef must be a code reference"
        unless ref($self->{+CODEREF}) && reftype($self->{+CODEREF}) eq 'CODE';

    $self->_deduce unless $self->{+DEDUCED};
}

sub _deduce {
    my $self = shift;

    my ($ok) = try { require B };
    return unless $ok;

    my $code    = $self->{+CODEREF};
    my $cobj    = B::svref_2object($code);
    my $pkg     = $cobj->GV->STASH->NAME;
    my $file    = $cobj->FILE;
    my $start   = $cobj->START;
    my $line    = $start->can('line') ? $start->line : -1;
    my $subname = $cobj->GV->NAME;

    $SUB_MAPS{$file}->{$line} = $self->{+NAME};

    $self->{+DEDUCED} = [$pkg, $file, $line, $subname];
    $self->{+NAME}  ||= $subname;
}

sub package { $_[0]->{+DEDUCED}->[PACKAGE] }
sub file    { $_[0]->{+DEDUCED}->[FILE]    }
sub subname { $_[0]->{+DEDUCED}->[SUBNAME] }

sub call_detail {
    my $self = shift;

    my $file = $self->file;

    my $start = $self->start_line;
    my $end   = $self->end_line;

    my $lines;
    if ($end && $end != $start) {
        $lines = "lines $start -> $end";
    }
    elsif ($end) {
        $lines = "line $start";
    }
    else {
        my ($dpkg, $dfile, $dline) = @{$self->caller};
        $lines = "line $start (declared in $dfile line $dline)";
    }

    return "$file $lines";
}

sub detail {
    my $self = shift;

    my $name  = $self->{+NAME};
    my $lines = $self->call_detail;

    my $known = "";
    if ($self->{+DEDUCED}->[SUBNAME] ne '__ANON__') {
        $known = " (" . $self->{+DEDUCED}->[SUBNAME] . ")";
    }

    return "${name}${known} in $lines";
}

sub start_line {
    my $self = shift;
    return $self->{+_START_LINE} if $self->{+_START_LINE};

    my $start = $self->{+DEDUCED}->[LINE];
    my $end   = $self->end_line || 0;

    if ($start == $end || $start == 1) {
        $self->{+_START_LINE} = $start;
    }
    else {
        $self->{+_START_LINE} = $start - 1;
    }

    return $self->{+_START_LINE};
}

sub end_line {
    my $self = shift;
    return $self->{+_END_LINE} if $self->{+_END_LINE};

    my $call = $self->{+CALLER};
    my $dedu = $self->{+DEDUCED};

    _map_package_file($dedu->[PACKAGE], $dedu->[FILE]);

    # Check if caller and deduced seem to be from the same place.
    my $match = $call->[PACKAGE] eq $dedu->[PACKAGE];
    $match &&= $call->[FILE] eq $dedu->[FILE];
    $match &&= $call->[LINE] >= $dedu->[LINE];

    if ($dedu->[SUBNAME] ne '__ANON__') {
        $match &&= !_check_interrupt($dedu->[FILE], $dedu->[LINE], $call->[LINE]);
    }

    if ($match) {
        $self->{+_END_LINE} = $call->[LINE];
        return $call->[LINE];
    }

    # Uhg, see if we can figure it out.
    my @lines = sort { $a <=> $b } keys %{$SUB_MAPS{$dedu->[FILE]}};
    for my $line (@lines) {
        next if $line <= $dedu->[LINE];
        $self->{+_END_LINE} = $line;
        $self->{+_END_LINE} -= 2 unless $SUB_MAPS{$dedu->[FILE]}->{$line} && $SUB_MAPS{$dedu->[FILE]}->{$line} eq '__EOF__';
        return $self->{+_END_LINE};
    }

    return undef;
}

sub _check_interrupt {
    my ($file, $start, $end) = @_;
    return 0 if $start == $end;

    my @lines = sort { $a <=> $b } keys %{$SUB_MAPS{$file}};

    for my $line (@lines) {
        next if $line <= $start;
        return $line <= $end;
    }

    return 0;
}

my %MAPPED;
sub _map_package_file {
    my ($pkg, $file) = @_;

    return if $MAPPED{$pkg}->{$file}++;

    require B;

    my %seen;
    my @symbols = do { no strict 'refs'; %{"$pkg\::"} };
    for my $sym (@symbols) {
        my $code = $pkg->can($sym) || next;
        next if $seen{$code}++;

        my $cobj = B::svref_2object($code);

        # Skip imported subs
        my $pname = $cobj->GV->STASH->NAME;
        next unless $pname eq $pkg;

        my $f = $cobj->FILE;
        next unless $f eq $file;

        # Skip XS/C Files
        next if $file =~ m/\.c$/;
        next if $file =~ m/\.xs$/;

        my $line = $cobj->START->line;
        $SUB_MAPS{$file}->{$line} ||= $sym;
    }

    if (open(my $fh, '<', $file)) {
        my $length = () = <$fh>;
        close($fh);
        $SUB_MAPS{$file}->{$length} = '__EOF__';
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Block - Tools to inspect coderefs

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

This module is used to find line numbers, files, and other data about
codeblocks. When used properly you can get both the start and end lines of
codeblocks.

=head1 SYNOPSIS

    use Test::Stream::Block;

    sub new_block {
        my ($name, $code) = @_;
        my $block = Test::Stream::Block->new(
            name    => $name,
            coderef => $code,
            caller  => [caller],
        );
        return $block;
    }

    my $block = new_block foo => sub {
        ...
    };

    my $start_line = $block->start_line;
    my $end_line = $block->end_line;

=head1 HOW IT WORKS

Using the L<B> module it is possible to get the line number of the first
statement in a subroutine from the coderef. This makes it possible to get a
rough approximation of the starting line number of a sub, usually it is off by
1, but will be correct for 1-line subs.

When you call a subroutine, then use C<caller()> to get where the subroutine
was called, you get the last line of the statement. If it is a 1 line statement
you get the line number. If the statement uses multiple lines you get the last
one.

    1: a_function "name" => sub { ... };

In the example above C<a_function()> can get the calling line number C<1> and
the line of the first statement in the codeblock (also C<1>). With this
information it could conclude that the codeblock is 1 line long, and is defined
on line 1.

    01: a_function $name => sub {
    02:     my $self = shift;
    03:     ...
    04:     return 1;
    05: };

In this example C<a_function> gets line number C<5> from C<caller()>. It can
also get line C<2> using L<B> to inspect the coderef. With this information it
can conclude that it is a multi-line codeblock, it knows that the first line is
probably off by one and concludes it actually starts on line C<1>. At this
point C<a_function()> knows that the codeblock starts on line 1 and end on line
5.

When you pass in a named sub it will try its best to get the line numbers, it
does this by actually reading in the file the sub was defined in and using some
logic to approximate things. This is an 80% solution, it will get some things
wrong.

=head2 CAVEATS

Some assumptions are made, for instance:

    01: a_function(
    02:     name => $name,
    03:     code => sub { ... },
    04: );

This will think the codeblock is defined from lines 2->4.

=head1 METHODS

=over 4

=item $name = $block->name

This return the name provided to the constructor, or the name as deduced from
the codeblock using L<B>.

=item $sub = $block->coderef

This returns the coderef used to create the block object.

=item $caller = $block->caller

This returns an arrayref with the caller details provided at construction.

=item $package $block->package

This returns the deduced package.

=item $file = $block->file

This returns the deduced file.

=item $name = $block->subname

This returns the deduced sub name.

=item $block->run(@args)

This will run the coderef using any arguments provided.

=item $string = $block->detail

This returns a detail string similar to C<'file foo.t line 5'>. If start and
end lines are known it will say C<'1 -> 4'>, etc. It will adapt itself to
provide whatever information it knows about the sub.

=item $line = $block->start_line

Get the starting line (or close to it).

=item $line = $block->end_line

Get the ending line (or close to it).

=item $arrayref = $block->deduced

Arrayref much like what you get from caller, but the details come from L<B>
instead.

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

=back

=head1 COPYRIGHT

Copyright 2015 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
