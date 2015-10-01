package Test::Stream::Compare::EventMeta;
use strict;
use warnings;

use Test::Stream::Compare::Meta;
use Test::Stream::HashBase(
    base => 'Test::Stream::Compare::Meta',
);

sub get_prop_file    { $_[1]->debug->file }
sub get_prop_line    { $_[1]->debug->line }
sub get_prop_package { $_[1]->debug->package }
sub get_prop_subname { $_[1]->debug->subname }
sub get_prop_skip    { $_[1]->debug->skip }
sub get_prop_todo    { $_[1]->debug->todo }
sub get_prop_trace   { $_[1]->debug->trace }
sub get_prop_tid     { $_[1]->debug->tid }
sub get_prop_pid     { $_[1]->debug->pid }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test::Stream::Compare::EventMeta - Meta class for events in deep comparisons

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

See F<http://www.perl.com/perl/misc/Artistic.html>

=cut
