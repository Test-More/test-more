package Test::Stream::Compare::EventMeta;
use strict;
use warnings;

use base 'Test::Stream::Compare::Meta';
use Test::Stream::HashBase;

use Carp qw/carp/;

sub get_prop_file    { $_[1]->debug->file }
sub get_prop_line    { $_[1]->debug->line }
sub get_prop_package { $_[1]->debug->package }
sub get_prop_subname { $_[1]->debug->subname }
sub get_prop_trace   { $_[1]->debug->trace }
sub get_prop_tid     { $_[1]->debug->tid }
sub get_prop_pid     { $_[1]->debug->pid }

sub get_prop_todo {
    my $self = shift;
    my ($thing) = @_;

    unless ($thing->can('todo')) {
        my $type = ref($thing);
        carp "Use of 'todo' property is deprecated for '$type'";
        return $thing->debug->_todo;    # deprecated
    }

    return $thing->todo || $thing->debug->_todo;
}

sub get_prop_skip {
    carp "Use of 'skip' property is deprecated";
    $_[1]->debug->_skip; # Private no-warning version until removed
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::EventMeta - Meta class for events in deep comparisons

=head1 DESCRIPTION

This is used in deep compariosns of event objects. You should probably never
use this directly.

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

See F<http://dev.perl.org/licenses/>

=cut
