package Test2::Formatter::TAP;
use strict;
use warnings;
require PerlIO;

our $VERSION = '1.302078';

use Test2::Util::HashBase qw{
    no_numbers handles _encoding last_fh
};

sub OUT_STD() { 0 }
sub OUT_ERR() { 1 }

BEGIN { require Test2::Formatter; our @ISA = qw(Test2::Formatter) }

sub _autoflush {
    my($fh) = pop;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;
}

_autoflush(\*STDOUT);
_autoflush(\*STDERR);

sub hide_buffered() { 1 }

sub init {
    my $self = shift;

    $self->{+HANDLES} ||= $self->_open_handles;
    if(my $enc = delete $self->{encoding}) {
        $self->encoding($enc);
    }
}

sub _open_handles {
    my $self = shift;

    my %seen;
    open(my $out, '>&', STDOUT) or die "Can't dup STDOUT:  $!";
    binmode($out, join(":", "", "raw", grep { $_ ne 'unix' and !$seen{$_}++ } PerlIO::get_layers(STDOUT)));

    %seen = ();
    open(my $err, '>&', STDERR) or die "Can't dup STDERR:  $!";
    binmode($err, join(":", "", "raw", grep { $_ ne 'unix' and !$seen{$_}++ } PerlIO::get_layers(STDERR)));

    _autoflush($out);
    _autoflush($err);

    return [$out, $err];
}

sub encoding {
    my $self = shift;

    if (@_) {
        my ($enc) = @_;
        my $handles = $self->{+HANDLES};

        # https://rt.perl.org/Public/Bug/Display.html?id=31923
        # If utf8 is requested we use ':utf8' instead of ':encoding(utf8)' in
        # order to avoid the thread segfault.
        if ($enc =~ m/^utf-?8$/i) {
            binmode($_, ":utf8") for @$handles;
        }
        else {
            binmode($_, ":encoding($enc)") for @$handles;
        }
        $self->{+_ENCODING} = $enc;
    }

    return $self->{+_ENCODING};
}

if ($^C) {
    no warnings 'redefine';
    *write = sub {};
}
sub write {
    my ($self, $e, $num, $f) = @_;

    my $tap = ref($e) eq 'Test2::Event::Pass'
        ? [$self->assert_tap($e, $f, $num)]
        : $self->event_tap($e, $f, $num);

    my $handles = $self->{+HANDLES};
    my $nesting = defined($e->{nested}) ? $e->{nested} || 0 : $e->nested || 0;
    my $indent = '    ' x $nesting;

    # Local is expensive! Only do it if we really need to.
    local($\, $,) = (undef, '') if $\ || $,;
    for my $set (@$tap) {
        no warnings 'uninitialized';
        my ($hid, $msg) = @$set;
        next unless $msg;
        my $io = $handles->[$hid] or next;

        print $io "\n"
            if $ENV{HARNESS_ACTIVE}
            && !$ENV{HARNESS_IS_VERBOSE}
            && $hid == OUT_ERR
            && $self->{+LAST_FH} != $io
            && $msg =~ m/^#\s*Failed test /;

        $msg =~ s/^/$indent/mg if $nesting;
        print $io $msg;
        $self->{+LAST_FH} = $io;
    }
}

sub event_tap {
    my ($self, $e, $f, $num) = @_;

    my @tap;

    # If this IS the first event the plan should come first
    # (plan must be before or after assertions, not in the middle)
    push @tap => $self->plan_tap($e, $f) if $num == 1 && $f->{plan};

    # The assertion is most important, if present.
    if ($f->{assert}) {
        push @tap => $self->assert_tap($e, $f, $num);
        push @tap => $self->debug_tap($e, $f, $num) unless $e->{no_debug} || $e->no_debug || $f->{assert}->{pass};
    }

    # Now lets see the diagnostics messages
    push @tap => $self->info_tap($e, $f) if $f->{info};

    # If this IS NOT the first event the plan should come last
    # (plan must be before or after assertions, not in the middle)
    push @tap => $self->plan_tap($e, $f) if $num != 1 && $f->{plan};

    # Bail out
    push @tap => $self->bail_tap($e, $f) if $f->{stop};

    # Use the summary as a fallback if nothing else is usable.
    push @tap => $self->summary_tap($e, $num) unless @tap || grep { $f->{$_} } qw/assert plan info stop/;

    return \@tap;
}

sub plan_tap {
    my $self = shift;
    my ($e, $f) = @_;
    my $plan = $f->{plan};

    return if $plan->none;

    if ($plan->skip) {
        my $reason = $plan->details or return [OUT_STD, "1..0 # SKIP\n"];
        chomp($reason);
        return [OUT_STD, '1..0 # SKIP ' . $reason . "\n"];
    }

    return [OUT_STD, "1.." . $plan->count . "\n"];

    return;
}

sub no_subtest_space() { 0 }
sub assert_tap {
    my $self = shift;
    my ($e, $f, $num) = @_;

    my $assert = $f->{assert};
    my $pass = $assert->{pass};
    my $name = $assert->{details};

    my $ok = $pass ? 'ok' : 'not ok';
    $ok .= " $num" unless $self->{+NO_NUMBERS};

    # The regex form is ~250ms, the index form is ~50ms
    my @extra;
    defined($name) && (
        (index($name, "\n") != -1 && (($name, @extra) = split(/\n\r?/, $name, -1))),
        ((index($name, "#" ) != -1  || substr($name, -1) eq '\\') && (($name =~ s|\\|\\\\|g), ($name =~ s|#|\\#|g)))
    );

    my $extra_space = @extra ? ' ' x (length($ok) + 2) : '';
    my $extra_indent = '';

    my ($directives, $reason, $is_skip);
    if ($f->{amnesty}) {
        my %directives;

        for my $am (@{$f->{amnesty}}) {
            next if $am->{inherited};
            my $action = $am->{action} or next;
            $is_skip = 1 if $action eq 'skip';

            $directives{$action} ||= $am->{details};
        }

        # Make sure TODO and skip come first, in that order
        my %seen;
        my @order = grep { exists($directives{$_}) && !$seen{$_}++ } 'TODO', 'skip', sort keys %directives;

        $directives = ' # ' . join ' & ' => @order;

        # PRefer skip reason over todo because legacy... bleh
        for my $action ('skip', @order) {
            next unless defined($directives{$action}) && length($directives{$action});
            $reason = $directives{$action};
            last;
        }
    }

    $ok .= " - $name" if defined $name && !($is_skip && !$name);

    my @subtap;
    if ($f->{nest} && $f->{nest}->{buffered}) {
        $ok .= ' {';

        # In a verbose harness we indent the extra since they will appear
        # inside the subtest braces. This helps readability. In a non-verbose
        # harness we do not do this because it is less readable.
        if ($ENV{HARNESS_IS_VERBOSE} || !$ENV{HARNESS_ACTIVE}) {
            $extra_indent = "    ";
            $extra_space = ' ';
        }

        # Render the sub-events, we use our own counter for these.
        my $count = 0;
        @subtap = map {
            my $f2 = $_->facets;

            # Bump the count for any event that should bump it.
            $count++ if $f->{assert};

            # This indents all output lines generated for the sub-events.
            # index 0 is the filehandle, index 1 is the message we want to indent.
            map { $_->[1] =~ s/^(.*\S.*)$/    $1/mg; $_ } @{$self->event_tap($_, $f2, $count)};
        } @{$f->{nest}->{events}};

        push @subtap => [OUT_STD, "}\n"];
    }

    if ($directives) {
        $directives = ' # TODO & SKIP' if $directives eq ' # TODO & skip';
        $ok .= $directives;
        $ok .= " $reason" if defined($reason);
    }

    $extra_space = ' ' if $self->no_subtest_space;

    my @out = ([OUT_STD, "$ok\n"]);
    push @out => map {[OUT_STD, "${extra_indent}#${extra_space}$_\n"]} @extra if @extra;
    push @out => @subtap;

    return @out;
}

sub debug_tap {
    my ($self, $e, $f, $num) = @_;

    # This behavior is inherited from Test::Builder which injected a newline at
    # the start of the first diagnostics when the harness is active, but not
    # verbose. This is important to keep the diagnostics from showing up
    # appended to the existing line, which is hard to read. In a verbose
    # harness there is no need for this.
    my $prefix = $ENV{HARNESS_ACTIVE} && !$ENV{HARNESS_IS_VERBOSE} ? "\n" : "";

    # Figure out the debug info, this is typically the file name and line
    # number, but can also be a custom message. If no trace object is provided
    # then we have nothing useful to display.
    my $name  = $f->{assert}->{details};
    my $trace = $e->trace;
    my $debug = $trace ? $trace->debug : "[No trace info available]";

    # Create the initial diagnostics. If the test has a name we put the debug
    # info on a second line, this behavior is inherited from Test::Builder.
    my $msg = defined($name)
        ? qq[# ${prefix}Failed test '$name'\n# $debug.\n]
        : qq[# ${prefix}Failed test $debug.\n];

    my $IO = $f->{amnesty} ? OUT_STD : OUT_ERR;

    return [$IO, $msg];
}

sub bail_tap {
    my ($self, $e, $f) = @_;

    return if $e->nested;
    my $stop = $f->{stop} or return;

    my $details = $stop->details;

    return [OUT_STD, "Bail out!\n"] unless defined($details) && length($details);
    return [OUT_STD, "Bail out!  $details\n"];
}

sub info_tap {
    my ($self, $e, $f) = @_;

    my $IO = $e->gravity > 0 ? OUT_ERR : OUT_STD;

    return map {
        my $details = $_->{details};

        my $msg;
        if (ref($details)) {
            require Data::Dumper;
            my $dumper = Data::Dumper->new([$details])->Indent(2)->Terse(1)->Pad('# ')->Useqq(1)->Sortkeys(1);
            chomp($msg = $dumper->Dumper);
        }
        else {
            chomp($msg = $details);
            $msg =~ s/^/# /;
            $msg =~ s/\n/\n# /g;
        }

        [$IO, "$msg\n"];
    } @{$f->{info}};
}

sub summary_tap {
    my ($self, $e, $num) = @_;

    return if $e->gravity < 0;

    my $summary = $e->summary or return;
    chomp($summary);
    $summary =~ s/^/# /smg;

    my $IO = $e->gravity > 0 ? OUT_ERR : OUT_STD;

    return [$IO, "$summary\n"];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Formatter::TAP - Standard TAP formatter

=head1 DESCRIPTION

This is what takes events and turns them into TAP.

=head1 SYNOPSIS

    use Test2::Formatter::TAP;
    my $tap = Test2::Formatter::TAP->new();

    # Switch to utf8
    $tap->encoding('utf8');

    $tap->write($event, $number); # Output an event

=head1 METHODS

=over 4

=item $bool = $tap->no_numbers

=item $tap->set_no_numbers($bool)

Use to turn numbers on and off.

=item $arrayref = $tap->handles

=item $tap->set_handles(\@handles);

Can be used to get/set the filehandles. Indexes are identified by the
C<OUT_STD> and C<OUT_ERR> constants.

=item $encoding = $tap->encoding

=item $tap->encoding($encoding)

Get or set the encoding. By default no encoding is set, the original settings
of STDOUT and STDERR are used.

This directly modifies the stored filehandles, it does not create new ones.

=item $tap->write($e, $num)

Write an event to the console.

=back

=head1 SOURCE

The source code repository for Test2 can be found at
F<http://github.com/Test-More/test-more/>.

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

Copyright 2016 Chad Granum E<lt>exodist@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See F<http://dev.perl.org/licenses/>

=cut
