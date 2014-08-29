package Test::Stream::Event::Ok;
use strict;
use warnings;

use base 'Test::Stream::Event';

use Carp qw/confess/;
use Scalar::Util qw/blessed/;

use Test::Stream qw/OUT_STD/;
use Test::Stream::Event;
BEGIN {
    accessors qw/real_bool name diag bool/;
    Test::Stream::Event->cleanup;
};

sub skip { $_[0]->[CONTEXT]->skip }
sub todo { $_[0]->[CONTEXT]->todo }

sub init {
    my $self = shift;
    my $ctx  = $self->[CONTEXT];
    my $rb   = $self->[REAL_BOOL];
    my $todo = $ctx->in_todo;
    my $skip = defined $ctx->skip;
    my $b    = $rb || $todo || $skip;
    my $diag = delete $self->[DIAG];
    my $name = $self->[NAME];

    $self->[BOOL] = $b;

    unless ($rb || ($todo && $skip)) {
        my $msg = $todo ? "Failed (TODO)" : "Failed";
        my $prefix = $ENV{HARNESS_ACTIVE} ? "\n" : "";

        my ($pkg, $file, $line) = $ctx->call;

        if (defined $name) {
            $msg = qq[$prefix  $msg test '$name'\n  at $file line $line.\n];
        }
        else {
            $msg = qq[$prefix  $msg test at $file line $line.\n];
        }

        $self->add_diag($msg);
    }

    $self->add_diag(@$diag) if $diag && @$diag;
}

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $name = $self->[NAME];
    my $skip = $self->[CONTEXT]->skip;
    my $todo = $self->[CONTEXT]->todo;

    my @out;
    push @out => "not" unless $self->[REAL_BOOL];
    push @out => "ok";
    push @out => $num if defined $num;

    if (defined $name) {
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        push @out => ("-", $name);
    }

    if (defined $skip && defined $todo) {
        unless ($skip eq $todo) {
            require Data::Dumper;
            confess "2 different reasons to skip/todo: " . $self->field_dump;
        }

        push @out => "# TODO & SKIP";
        push @out => $todo if length $todo;
    }
    elsif (defined $todo) {
        push @out => "# TODO";
        push @out => $todo if length $todo;
    }
    elsif (defined $skip) {
        push @out => "# skip";
        push @out => $skip if length $skip;
    }

    my $out = join " " => @out;
    $out =~ s/\n/\n# /g;

    return (OUT_STD, "$out\n");
}

sub add_diag {
    my $self = shift;

    my $context = $self->[CONTEXT];
    my $created = $self->[CREATED];

    for my $item (@_) {
        next unless $item;

        unless (ref $item) {
            $item = Test::Stream::Event::Diag->new($context, $created, $item, $self);
            next;
        }

        confess "Only diag objects can be linked to events."
            unless blessed($item) && $item->isa('Test::Stream::Event::Diag');
    
        $item->link($self);
        push @{$self->[DIAG]} => $item;
    }
}

{
    # Yes, we do want to override the imported one.
    no warnings 'redefine';
    sub clear_diag {
        my $self = shift;
        return unless $self->[DIAG];
        my $out = $self->[DIAG];
        $self->[DIAG] = undef;
        $_->clear_linked for @$out;
        return $out;
    }
}

1;

__END__

=head1 NAME

Test::Stream::Event::Ok - Ok event type

=head1 DESCRIPTION

The ok event type.

=head1 METHODS

See L<Test::Stream::Event> which is the base class for this module.

=head2 CONSTRUCTORS

=over 4

=item $r = $class->new(...)

Create a new instance

=back

=head2 INFORMATION

=over 4

=item $r->to_tap

Returns the TAP string for the plan (not indented).

=item $r->indent

Returns the indentation that should be used to display the event ('    ' x
depth).

=back

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
