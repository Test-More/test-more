package Test::Stream::Context;
use strict;
use warnings;

use Scalar::Util qw/blessed weaken/;

use Test::Stream::Carp qw/confess/;

use Test::Stream;
use Test::Stream::Threads;
use Test::Stream::Event();
use Test::Stream::Util qw/try/;
use Test::Stream::Meta qw/init_tester is_tester/;

use Test::Stream::ArrayBase(
    accessors => [qw/frame stream encoding in_todo todo modern pid skip diag_todo provider/],
);

use Test::Stream::Exporter qw/import export_to default_exports/;
default_exports qw/context/;
Test::Stream::Exporter->cleanup();

{
    no warnings 'once';
    $Test::Builder::Level ||= 1;
}

my $CURRENT;

sub init {
    $_[0]->[FRAME]    ||= _find_context(1);                # +1 for call to init
    $_[0]->[STREAM]   ||= Test::Stream->shared;
    $_[0]->[ENCODING] ||= 'legacy';
    $_[0]->[PID]      ||= $$;
}

sub peek  { $CURRENT }
sub clear { $CURRENT = undef }

sub set {
    $CURRENT = pop;
    weaken($CURRENT);
}

sub context {
    my ($level, $stream) = @_;
    # If the context has already been initialized we simply return it, we
    # ignore any additional parameters as they no longer matter. The first
    # thing to ask for a context wins, anything context aware that is called
    # later MUST expect that it can get a context found by something down the
    # stack.
    if ($CURRENT) {
        return $CURRENT unless $stream;
        return $CURRENT if $stream == $CURRENT->[STREAM];
    }

    my $call = _find_context($level);
    $call = _find_context_harder() unless $call;
    my $pkg  = $call->[0];

    my $meta = is_tester($pkg) || _find_tester();

    # Check if $TODO is set in the package, if not check if Test::Builder is
    # loaded, and if so if it has Todo set. We check the element directly for
    # performance.
    my ($todo, $in_todo);
    {
        my $todo_pkg = $meta->[Test::Stream::Meta::PACKAGE];
        no strict 'refs';
        no warnings 'once';
        if ($todo = $meta->[Test::Stream::Meta::TODO]) {
            $in_todo = 1;
        }
        elsif ($todo = ${"$todo_pkg\::TODO"}) {
            $in_todo = 1;
        }
        elsif ($Test::Builder::Test && defined $Test::Builder::Test->{Todo}) {
            $todo    = $Test::Builder::Test->{Todo};
            $in_todo = 1;
        }
        else {
            $in_todo = 0;
        }
    };

    my ($ppkg, $pname);
    if(my @provider = caller(1)) {
        ($ppkg, $pname) = ($provider[3] =~ m/^(.*)::([^:]+)$/);
    }

    $stream ||= $meta->[Test::Stream::Meta::STREAM] || Test::Stream->shared || confess "No Stream!?";
    if ((USE_THREADS || $stream->_use_fork) && ($stream->pid == $$ && $stream->tid == get_tid())) {
        $stream->fork_cull();
    }

    my $ctx = bless(
        [
            $call,
            $stream,
            $meta->[Test::Stream::Meta::ENCODING] || 'legacy',
            $in_todo,
            $todo,
            $meta->[Test::Stream::Meta::MODERN]   || 0,
            $$,
            undef,
            $in_todo,
            [$ppkg, $pname]
        ],
        __PACKAGE__
    );

    return $ctx if $CURRENT;

    $CURRENT = $ctx;
    weaken($CURRENT);
    return $ctx;
}

sub _find_context {
    my ($add) = @_;

    $add ||= 0;
    my $tb = $Test::Builder::Level - 1;

    # 0 - call to find_context
    # 1 - call to context/new
    # 2 - call to tool
    my $level = 2 + $add + $tb;
    my ($package, $file, $line, $subname) = caller($level);

    return unless $package;

    while ($package eq 'Test::Builder') {
        ($package, $file, $line, $subname) = caller(++$level);
    }

    return unless $package;

    return [$package, $file, $line, $subname];
}

sub _find_context_harder {
    my $level = 0;
    my $fallback;
    while(1) {
        my ($pkg, $file, $line, $subname) = caller($level++);
        $fallback ||= [$pkg, $file, $line, $subname] if $subname =~ m/::END$/;
        next if $pkg =~ m/^Test::(Stream|Builder|More|Simple)(::.*)?$/;
        return [$pkg, $file, $line, $subname];
    }

    return $fallback if $fallback;
    return [ '<UNKNOWN>', '<UNKNOWN>', 0, '<UNKNOWN>' ];
}

sub _find_tester {
    my $level = 2;
    while(1) {
        my $pkg = caller($level++);
        last unless $pkg;
        my $meta = is_tester($pkg) || next;
        return $meta;
    }

    # find a .t file!
    $level = 0;
    while(1) {
        my ($pkg, $file) = caller($level++);
        last unless $pkg;
        if ($file eq $0 && $file =~ m/\.t$/) {
            return init_tester($pkg);
        }
    }

    return init_tester('main');
}

sub done_testing {
    $_[0]->stream->done_testing(@_);
}

sub alert {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    warn "$msg at $call[1] line $call[2].\n";
}

sub throw {
    my $self = shift;
    my ($msg) = @_;

    my @call = $self->call;

    $CURRENT = undef if $CURRENT = $self;

    die "$msg at $call[1] line $call[2].\n";
}

sub call { @{$_[0]->[FRAME]} }

sub package { $_[0]->[FRAME]->[0] }
sub file    { $_[0]->[FRAME]->[1] }
sub line    { $_[0]->[FRAME]->[2] }
sub subname { $_[0]->[FRAME]->[3] }

sub snapshot {
    return bless [@{$_[0]}], blessed($_[0]);
}

sub send {
    my $self = shift;
    $self->[STREAM]->send(@_);
}

sub register_event {
    my $class = shift;
    my ($pkg) = @_;
    my $name = lc($pkg);
    $name =~ s/^.*:://g;

    confess "Method '$name' is already defined, event '$pkg' cannot get a context method!"
        if $class->can($name);

    # Use a string eval so that we get a names sub instead of __ANON__
    local ($@, $!);
    eval qq|
        sub $name {
            my \$self = shift;
            my \@call = caller(0);
            my \$e = '$pkg'->new(\$self->snapshot, [\@call[0 .. 4]], 0, \@_);
            return \$self->stream->send(\$e);
        };
        1;
    | || die $@;
}

sub hide_todo {
    my $self = shift;
    no strict 'refs';
    no warnings 'once';

    my $pkg = $self->[FRAME]->[0];
    my $meta = is_tester($pkg);

    my $found = {
        TB   => $Test::Builder::Test ? $Test::Builder::Test->{Todo} : undef,
        META => $meta->[Test::Stream::Meta::TODO],
        PKG  => ${"$pkg\::TODO"},
    };

    $Test::Builder::Test->{Todo} = undef;
    $meta->[Test::Stream::Meta::TODO] = undef;
    ${"$pkg\::TODO"} = undef;

    return $found;
}

sub restore_todo {
    my $self = shift;
    my ($found) = @_;
    no strict 'refs';
    no warnings 'once';

    my $pkg = $self->[FRAME]->[0];
    my $meta = is_tester($pkg);

    $Test::Builder::Test->{Todo} = $found->{TB};
    $meta->[Test::Stream::Meta::TODO] = $found->{META};
    ${"$pkg\::TODO"} = $found->{PKG};

    my $found2 = {
        TB   => $Test::Builder::Test ? $Test::Builder::Test->{Todo} : undef,
        META => $meta->[Test::Stream::Meta::TODO] || undef,
        PKG  => ${"$pkg\::TODO"} || undef,
    };

    for my $k (qw/TB META PKG/) {
        no warnings 'uninitialized';
        next if "$found->{$k}" eq "$found2->{$k}";
        die "Mismatch! $k:\t$found->{$k}\n\t$found2->{$k}\n"
    }

    return;
}

sub DESTROY { 1 }

our $AUTOLOAD;
sub AUTOLOAD {
    my $class = blessed($_[0]) || $_[0] || confess $AUTOLOAD;

    my $name = $AUTOLOAD;
    $name =~ s/^.*:://g;

    my $module = 'Test/Stream/Event/' . ucfirst(lc($name)) . '.pm';
    try { require $module };

    my $sub = $class->can($name);
    goto &$sub if $sub;

    my ($pkg, $file, $line) = caller;

    die qq{Can't locate object method "$name" via package "$class" at $file line $line.\n};
}

1;

__END__

=encoding utf8

=head1 SOURCE

The source code repository for Test::More can be found at
F<http://github.com/Test-More/test-more/>.

=head1 MAINTAINER

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=back

=head1 AUTHORS

The following people have all contributed to the Test-More dist (sorted using
VIM's sort function).

=over 4

=item Chad Granum E<lt>exodist@cpan.orgE<gt>

=item Fergal Daly E<lt>fergal@esatclear.ie>E<gt>

=item Mark Fowler E<lt>mark@twoshortplanks.comE<gt>

=item Michael G Schwern E<lt>schwern@pobox.comE<gt>

=item 唐鳳

=back

=head1 COPYRIGHT

=over 4

=item Test::Stream

=item Test::Tester2

Copyright 2014 Chad Granum E<lt>exodist7@gmail.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::Simple

=item Test::More

=item Test::Builder

Originally authored by Michael G Schwern E<lt>schwern@pobox.comE<gt> with much
inspiration from Joshua Pritikin's Test module and lots of help from Barrie
Slaymaker, Tony Bowden, blackstar.co.uk, chromatic, Fergal Daly and the perl-qa
gang.

Idea by Tony Bowden and Paul Johnson, code by Michael G Schwern
E<lt>schwern@pobox.comE<gt>, wardrobe by Calvin Klein.

Copyright 2001-2008 by Michael G Schwern E<lt>schwern@pobox.comE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://www.perl.com/perl/misc/Artistic.html>

=item Test::use::ok

To the extent possible under law, 唐鳳 has waived all copyright and related
or neighboring rights to L<Test-use-ok>.

This work is published from Taiwan.

L<http://creativecommons.org/publicdomain/zero/1.0>

=item Test::Tester

This module is copyright 2005 Fergal Daly <fergal@esatclear.ie>, some parts
are based on other people's work.

Under the same license as Perl itself

See http://www.perl.com/perl/misc/Artistic.html

=item Test::Builder::Tester

Copyright Mark Fowler E<lt>mark@twoshortplanks.comE<gt> 2002, 2004.

This program is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=back
