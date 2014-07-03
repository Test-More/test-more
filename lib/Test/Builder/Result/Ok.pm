package Test::Builder::Result::Ok;
use strict;
use warnings;

use parent 'Test::Builder::Result';

use Data::Dumper;

use Carp qw/confess/;
use Test::Builder::Util qw/accessors/;

accessors qw/bool real_bool name todo skip/;

sub to_tap {
    my $self = shift;
    my ($num) = @_;

    my $out = "";
    $out .= "not " unless $self->real_bool;
    $out .= "ok";
    $out .= " $num" if defined $num;

    if (defined $self->name) {
        my $name = $self->name;
        $name =~ s|#|\\#|g;    # # in a name can confuse Test::Harness.
        $out .= " - " . $name;
    }

    if (defined $self->skip && defined $self->todo) {
        my $why = $self->skip;

        confess "2 different reasons to skip/todo: " . Dumper($self)
            unless $why eq $self->todo;

        $out .= " # TODO & SKIP $why";
    }
    elsif (defined $self->skip) {
        $out .= " # skip";
        $out .= " " . $self->skip if length $self->skip;
    }
    elsif($self->in_todo) {
        $out .= " # TODO " . $self->todo if $self->in_todo;
    }

    $out =~ s/\n/\n# /g;

    $out .= "\n";

    return $out;
}

1;

__END__

=head1 NAME

Test::Builder::Result::Ok - Ok result type

=head1 DESCRIPTION

The ok result type.

=head1 METHODS

See L<Test::Builder::Result> which is the base class for this module.

=head2 CONSTRUCTORS

=over 4

=item $r = $class->new(...)

Create a new instance

=back

=head2 SIMPLE READ/WRITE ACCESSORS

=over 4

=item $r->bool

True if the test passed, or if we are in a todo/skip

=item $r->real_bool

True if the test passed, false otherwise, even in todo.

=item $r->name

Name of the test.

=item $r->todo

Reason for todo (may be empty, even in a todo, check in_todo().

=item $r->skip

Reason for skip

=item $r->trace

Get the test trace info, including where to report errors.

=item $r->pid

PID in which the result was created.

=item $r->depth

Builder depth of the result (0 for normal, 1 for subtest, 2 for nested, etc).

=item $r->in_todo

True if the result was generated inside a todo.

=item $r->source

Builder that created the result, usually $0, but the name of a subtest when
inside a subtest.

=item $r->constructed 

Package, File, and Line in which the result was built.

=back

=head2 INFORMATION

=over 4

=item $r->to_tap

Returns the TAP string for the plan (not indented).

=item $r->type

Type of result. Usually this is the lowercased name from the end of the
package. L<Test::Builder::Result::Ok> = 'ok'.

=item $r->indent

Returns the indentation that should be used to display the result ('    ' x
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
