package Test::Builder2::OnlyOnePlan;

use strict;
use warnings;

use Carp;

use Test::Builder2::Mouse;
with 'Test::Builder2::EventWatcher';


=head1 NAME

Test::Builder2::OnlyOnePlan - Enforces there being only one plan per test

=head1 SYNOPSIS

    # Add an instance of this to the TestState to enforce plans
    use Test::Builder2::OnlyOnePlan;
    $test_state->add_early_watchers( Test::Builder2::OnlyOnePlan->new );


=head1 DESCRIPTION

This is a L<Test::Builder2::EventWatcher> which enforces there being
only one plan issued per test.

There are exceptions...

=head3 subtests have their own plan

Subtests must have their own plan, so that is allowed.

=head3 Multiple "no_plan"s are allowed

There's no harm in setting "no_plan" multiple times.  This
specifically allows...

    use Test::More "no_plan";

    ...test test test...

    done_testing();


=head3 Setting a fixed plan is allowed after a "no_plan"

There is no harm in raising the specificity of the plan.  This
specifically allows...

    use Test::More "no_plan";

    ...test test test...

    done_testing(5);

=cut

has plan        =>
  is            => 'rw',
  isa           => 'Test::Builder2::Event',
;

sub accept_set_plan {
    my $self  = shift;
    my $event = shift;

    $self->already_saw_plan($event) if $self->plan;

    $self->plan($event);

    return;
}


sub already_saw_plan {
    my $self = shift;
    my $new_plan = shift;

    my $plan = $self->plan;

    if(
        $plan->no_plan          &&
        (
            $new_plan->no_plan          ||
            $new_plan->asserts_expected
        )
    ) {
        $self->plan($new_plan);
        return;
    }

    croak("Already saw a plan");
}


__PACKAGE__->meta->make_immutable();
no Test::Builder2::Mouse;
