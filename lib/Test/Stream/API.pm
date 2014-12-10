package Test::Stream::API;
use strict;
use warnings;

use Test::Stream::Tester qw/intercept            /;
use Test::Stream         qw/cull tap_encoding    /;
use Test::Stream::Meta   qw/is_tester init_tester/;
use Test::Stream::Carp   qw/croak confess        /;

use Test::Stream::Exporter qw/import exports export_to/;
exports qw{
    listen munge follow_up
    enable_forking cull
    disable_tap enable_tap subtest_tap_instant subtest_tap_delayed tap_encoding use_numbers
    peek_todo push_todo pop_todo set_todo inspect_todo
    is_tester init_tester
    is_modern set_modern
    context peek_context clear_context set_context
    intercept
    state_count state_failed state_plan state_ended
    current_stream
};
Test::Stream::Exporter->cleanup();

BEGIN {
    require Test::Stream::Context;
    Test::Stream::Context->import(qw/context inspect_todo/);
    *peek_context  = \&Test::Stream::Context::peek;
    *clear_context = \&Test::Stream::Context::clear;
    *set_context   = \&Test::Stream::Context::set;
    *push_todo     = \&Test::Stream::Context::push_todo;
    *pop_todo      = \&Test::Stream::Context::pop_todo;
    *peek_todo     = \&Test::Stream::Context::peek_todo;
}

sub listen(&)       { Test::Stream->shared->listen($_[0])    }
sub munge(&)        { Test::Stream->shared->munge($_[0])     }
sub follow_up(&)    { Test::Stream->shared->follow_up($_[0]) }
sub enable_forking  { Test::Stream->shared->use_fork()       }
sub disable_tap     { Test::Stream->shared->set_use_tap(0)   }
sub enable_tap      { Test::Stream->shared->set_use_tap(1)   }
sub enable_numbers  { Test::Stream->set_use_numbers(1)       }
sub disable_numbers { Test::Stream->set_use_numbers(0)       }
sub current_stream  { Test::Stream->shared()                 }
sub state_count     { Test::Stream->shared->count()          }
sub state_failed    { Test::Stream->shared->failed()         }
sub state_plan      { Test::Stream->shared->plan()           }
sub state_ended     { Test::Stream->shared->ended()          }
sub is_passing      { Test::Stream->shared->is_passing       }

sub subtest_tap_instant {
    Test::Stream->set_subtest_tap_instant(1);
    Test::Stream->set_subtest_tap_delayed(0);
}

sub subtest_tap_delayed {
    Test::Stream->set_subtest_tap_instant(0);
    Test::Stream->set_subtest_tap_delayed(1);
}

sub is_modern {
    my ($package) = @_;
    my $meta = is_tester($package) || croak "'$package' is not a tester package";
    return $meta->modern ? 1 : 0;
}

sub set_modern {
    my $package = shift;
    croak "set_modern takes a package and a value" unless @_;
    my $value = shift;
    my $meta = is_tester($package) || croak "'$package' is not a tester package";
    return $meta->set_modern($value);
}

sub set_todo {
    my ($pkg, $why) = @_;
    my $meta = is_tester($pkg) || croak "'$pkg' is not a tester package";
    $meta->set_todo($why);
}

__END__

=head1 NAME

Test::Stream::API - Single point of access to Test::Stream extendability
features.

=head1 DESCRIPTION

There are times where you want to extend or alter the bahvior of a test file or
test suite. This module collects all the features and tools that
L<Test::Stream> offers for such actions. Everything in this file is accessible
in other places, but with less sugar coating.

=head1 SYNOPSYS

This synopsys is woefully limited, but there is just too much in the API to put
it all right here. So instead here is how you modify events, and add follow-up
behavior, the 2 most common types of extension.

    use Test::Stream::API qw/ munge follow_up is_passing /;

    munge {
        my ($stream, $event, @subevents) = @_;

        # Only modify diagnostics messages
        return unless $event->isa('Test::Stream::Diag');

        $event->set_message( "KILROY WAS HERE: " . $event->message );
    };

    follow_up {
        if (is_passing()) {
            print "KILROY Says the test file passed!\n";
        }
        else {
            print "KILROY is not happy with you!\n";
        }
    };

=head1 EXPORTED FUNCTIONS

All of these are functions. These functions all effect the current-shared
<Test::Stream> object only.

=head2 EVENT MANAGEMENT

These let you install a callback that is triggered for all primary events. The
first argument is the L<Test::Stream> object, the second is the primary
L<Test::Stream::Event>, any additional arguments are subevents. All subevents
are L<Test::Stream::Event> objects which are directly tied to the primary one.
The main example of a subevent is the failure L<Test::Stream::Event::Diag>
object associated with a failed L<Test::Stream::Event::Ok>, events within a
subtest are another example.

=over 4

=item listen { my ($stream, $event, @subevents) = @_; ... }

Listen callbacks happen just after TAP is rendered (or just after it would be
rendered if TAP is disabled).

=item munge { my ($stream, $event, @subevents) = @_; ... }

Muinspect_todonge callbacks happen just before TAP is rendered (or just before
it would be rendered if TAP is disabled).

=back

=head2 POST-TEST BEHAVIOR

=over 4

=item follow_up { my ($context) = @_; ... }

A followup callback allows you to install behavior that happens either when
C<done_testing()> is called, or when the test ends.

B<CAVEAT:> If done_testing is not used, the callback will happen in the
C<END {...}> block used by L<Test::Stream> to enact magic at the end of the
test.

=back

=head2 CONCURRENCY

=over 4

enable_forking
cull

=back

=head2 CONTROL OVER TAP

=over 4

disable_tap
enable_tap
subtest_tap_instant
subtest_tap_delayed
tap_encoding
use_numbers

=back

=head2 TEST PACKAGE METADATA

=over 4

is_modern
set_modern

=back

=head2 TODO MANAGEMENT

=over 4

peek_todo
push_todo
pop_todo
set_todo
inspect_todo

=back

=head2 TEST PACKAGE MANAGEMENT

=over 4

is_tester
init_tester

=back

=head2 CONTEXTUAL INFORMATION

=over 4

context
current_stream

=back

=head2 CAPTURING EVENTS

=over 4

intercept

=back

=head2 TEST STATE

=over 4

state_count
state_failed
state_plan
state_ended
is_passing

=back

=head1 GENERATING EVENTS

=head1 MODIFYING EVENTS

=head1 REPLACING TAP WITH ALTERNATIVE OUTPUT

=head1 END OF TEST BEHAVIORS

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

There has been a lot of code migration between modules,
here are all the original copyrights together:

=over 4

=item Test::Stream

=item Test::Stream::Tester

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
