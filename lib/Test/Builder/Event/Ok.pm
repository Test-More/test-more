package Test::Builder::Event::Ok;
use strict;
use warnings;

use base 'Test::Builder::Event';

use Carp qw/confess/;
use Scalar::Util qw/blessed reftype/;

sub bool      { $_[0]->{bool}      }
sub real_bool { $_[0]->{real_bool} }
sub name      { $_[0]->{name}      }
sub diag      { $_[0]->{diag}      }

sub skip { $_[0]->{context}->skip }
sub todo { $_[0]->{context}->todo }

sub init {
    my ($self, $context, $real_bool, $name, @diag) = @_;

    $self->{real_bool} = $real_bool;
    $self->{bool} = ($real_bool || $context->in_todo || $context->skip) ? 1 : 0;
    $self->{name} = $name;

    $self->_init_diag($context, $name) unless $real_bool || ($context->in_todo && $context->skip);

    $self->add_diag(@diag) if @diag;
}

sub _init_diag {
    my $self = shift;
    my ($context, $name) = @_;

    my $msg    = $context->in_todo    ? "Failed (TODO)" : "Failed";
    my $prefix = $ENV{HARNESS_ACTIVE} ? "\n"            : "";

    my ($pkg, $file, $line) = $context->call;

    if (defined $name) {
        $msg = qq[$prefix  $msg test '$name'\n  at $file line $line.\n];
    }
    else {
        $msg = qq[$prefix  $msg test at $file line $line.\n];
    }

    $self->add_diag($msg);
}

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $out = "";
    $out .= "not " unless $self->{real_bool};
    $out .= "ok";
    $out .= " $num" if defined $num;

    my $name = $self->{name};
    if (defined $name) {
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        $out .= " - " . $name;
    }

    my $skip = $self->skip;
    my $todo = $self->todo;
    if (defined $skip && defined $todo) {
        unless ($skip eq $todo) {
            require Data::Dumper;
            confess "2 different reasons to skip/todo: " . Data::Dumper::Dumper($self);
        }

        $out .= " # TODO & SKIP";
        $out .= " $todo" if length $todo;
    }
    elsif (defined $todo) {
        $out .= " # TODO";
        $out .= " $todo" if length $todo;
    }
    elsif (defined $skip) {
        $out .= " # skip";
        $out .= " $skip" if length $skip;
    }

    $out =~ s/\n/\n# /g;
    $out .= "\n";

    return $out;
}

sub clear_diag {
    my $self = shift;
    my @out = @{delete $self->{diag} || []};
    $_->linked(undef) for @out;
    return @out;
}

sub add_diag {
    my $self = shift;

    my $context = $self->{context};
    my $created = $self->{created};

    $self->{diag} ||= [];
    my $diag = $self->{diag};

    for my $item (@_) {
        next unless $item;

        unless (ref $item) {
            push @$diag => Test::Builder::Event::Diag->new($context, $created, $item);
            next;
        }

        confess "Only diag objects can be linked to events."
            unless blessed($item) && $item->isa('Test::Builder::Event::Diag');
    
        push @$diag => $item;
    }
}

1;

__END__

=head1 NAME

Test::Builder::Event::Ok - Ok event type

=head1 DESCRIPTION

The ok event type.

=head1 METHODS

See L<Test::Builder::Event> which is the base class for this module.

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
