package Test::Stream::DeepCheck::Object;
use strict;
use warnings;

use Scalar::Util qw/blessed/;
use Carp qw/confess/;

use Test::Stream::DeepCheck::Util qw/render_var/;
use Test::Stream::Util qw/try/;

use Test::Stream::DeepCheck::Meta;
use Test::Stream::HashBase(
    base => 'Test::Stream::DeepCheck::Meta',
    accessors => [qw/methods/],
);

sub init {
    $_[0]->SUPER::init();
    $_[0]->{+METHODS} = [];
}

sub add_method {
    my $self = shift;
    my %params = @_;

    my $meth  = $params{method};
    my $check = $params{check};
    my $args  = $params{args};
    my $wrap  = $params{wrap};

    confess "method is required" unless $meth;
    confess "check is required" unless $check;

    confess "Wrap must be set to '{' or '[', not '$wrap'"
        if $wrap && $wrap !~ m/^(\[|\{)$/;

    confess "Check must either be a 'Test::Stream::DeepCheck::Check' or 'Test::Stream::DeepCheck::Meta' object"
        unless $check->isa('Test::Stream::DeepCheck::Check')
            || $check->isa('Test::Stream::DeepCheck::Meta');

    push @{$self->{+METHODS}} => \%params;

    return unless $self->{+_BUILDER} && $check->_builder;
    return if @{$self->{+METHODS}} > 1;

    $self->{+DEBUG}->frame->[2] = $check->debug->line - 1
        if $check->debug->line < $self->{+DEBUG}->line;
}

sub path {
    my $self = shift;
    my ($parent_path, $child) = @_;

    my $meth  = $child->{method};
    my $args  = $child->{args};
    my $wrap  = $child->{wrap};

    return render_method($meth, $args, $wrap, $parent_path);
}

sub verify_object {
    my $self = shift;
    my ($got, $state) = @_;

    if (!$got) {
        my $mdbg = $self->{+DEBUG};
        $state->set_check_diag("blessed(undef)");
        push @{$state->diag} => [ $mdbg->file, $mdbg->line, "Expected a blessed reference, but got undef." ];
        return 0;
    }

    if (!blessed($got)) {
        my $mdbg = $self->{+DEBUG};
        $state->set_check_diag("blessed(" . render_var($got) . ")");
        push @{$state->diag} => [ $mdbg->file, $mdbg->line, "Expected a blessed reference, but got '$got'." ];
        return 0;
    }

    my $methods = $self->{+METHODS};

    for my $set (@$methods) {
        my $meth  = $set->{method};
        my $check = $set->{check};
        my $args  = $set->{args};
        my $wrap  = $set->{wrap};

        my $val;
        if ($wrap) {
            $val = $wrap eq '{'
                ? { $got->$meth($args ? @$args : ()) }
                : [ $got->$meth($args ? @$args : ()) ];
        }
        else {
            $val = $got->$meth($args ? @$args : ());
        }

        push @{$state->path} => $set;

        my $bool;
        my ($ok, $err) = try { $bool = $check->verify($val, $state) };

        if ($bool && $ok) {
            pop @{$state->path};
            next;
        }

        $state->set_error($err) unless $ok;

        my $mdbg = $self->{+DEBUG};
        my $ourline = [ $mdbg->file, $mdbg->line, 'bless(' ];

        my $rmeth = render_method($meth, $args, $wrap, '$_');

        if ($check->isa('Test::Stream::DeepCheck::Check')) {
            my $cdiag = $check->diag($val);
            $state->set_check_diag($cdiag);
            my $cdbg = $check->debug;
            push @{$state->diag} => [ $cdbg->file, $cdbg->line, "$rmeth: $cdiag" ];
        }
        elsif ($check->isa('Test::Stream::DeepCheck::Meta')) {
            # Modify the diag it already inserted
            $state->diag->[-1]->[2] = "$rmeth: " . $state->diag->[-1]->[2];
        }

        push @{$state->diag} => $ourline;

        return 0;
    }

    return 1;
}

sub render_method {
    my ($meth, $args, $wrap, $inst) = @_;

    my $sname;
    if (ref $meth) {
        my ($ok) = try { require B };
        if ($ok) {
            my $cobj    = B::svref_2object($meth);
            my $line    = $cobj->START->line;
            my $subname = $cobj->GV->NAME;
            my $pkg     = $cobj->GV->STASH->NAME;
            $subname =~ s/__ANON__$/ANON_SUB_LINE_$line/;
            $sname = "$pkg\::$subname";
        }
        else {
            $sname = '__ANON__'
        }
    }
    else {
        $sname = $meth;
    }

    my $rargs = $args ? join(', ', map {render_var($_)} @$args) : '';
    my $rmeth = (length($rargs) > 40) ? "$sname(...)" : "$sname($rargs)";

    return "$inst\->$rmeth" unless $wrap;

    my $pair = $wrap eq '{' ? '}' : ']';
    return "$wrap $inst\->$rmeth $pair";
}

sub verify {
    my $self = shift;
    my ($got, $state) = @_;

    # if it already failed we would not be here
    # if it already passed returning 1 is fine
    # if it is recursive then it has been true so far, return true, other
    # checks will catch any failures. 
    return 1 if $state->seen->{$self}->{$got}++;

    $self->verify_meta(@_) || return 0;

    push @{$state->path} => $self;
    $self->verify_object(@_) || return 0;
    pop @{$state->path};

    return 1;
}


1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::DeepCheck::Object - Class for doing deep object checks

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

This package represents a deep check of an object datastructure.

=head1 SUBCLASSES

This class subclasses L<Test::Stream::DeepCheck::Meta>.

=head1 METHODS

=over 4

=item $object->add_method(meth => $meth, check => $check, args => \@args, wrap => '[')

=item $object->add_method(meth => $meth, check => $check, args => \@args, wrap => '{')

Add a method check to the object checks.

=item $object->verify_object($got, $state)

Used to verify an object against the checks.

=item $object->verify($got, $state)

Used to verify an object against the checks and meta-checks.

=item $dbg = $object->debug

File+Line info for the state. This will be an L<Test::Stream::DebugInfo>
object.

=item $object->path($parent, $child)

Used internally, not intended for outside use.

=item $object->render_method

Used internally, not intended for outside use.

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
