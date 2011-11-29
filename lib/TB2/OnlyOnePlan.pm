package TB2::OnlyOnePlan;

use TB2::Mouse;
with 'TB2::EventHandler';

our $VERSION = '1.005000_002';
$VERSION = eval $VERSION;    ## no critic (BuiltinFunctions::ProhibitStringyEval)

use Carp;



=head1 NAME

TB2::OnlyOnePlan - Enforces there being only one plan per test

=head1 SYNOPSIS

    # Add an instance of this to the TestState to enforce plans
    use TB2::OnlyOnePlan;
    $test_state->add_early_handlers( TB2::OnlyOnePlan->new );


=head1 DESCRIPTION

This is a L<TB2::EventHandler> which enforces there being
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


=head3 Setting a fixed plan the same as the existing fixed plan.

This specificially allows redundant planning...

    use Test::More tests => 3;

    pass("One");
    pass("Two");
    pass("Three");

    done_testing(3);

=cut

has existing_plan =>
  is            => 'rw',
  isa           => 'Object',
;

sub handle_set_plan {
    my $self  = shift;
    my $event = shift;

    $self->already_saw_plan($event) if $self->existing_plan;

    $self->existing_plan($event);

    return;
}


sub already_saw_plan {
    my $self = shift;
    my $new_plan = shift;

    my $existing_plan = $self->existing_plan;

    return if $existing_plan->no_plan &&
              ( $new_plan->no_plan || $new_plan->asserts_expected );

    my $asserts_expected = $existing_plan->asserts_expected;
    return if $asserts_expected && $asserts_expected == $new_plan->asserts_expected;

    my $error = "Tried to set a plan" . $self->_plan_location($new_plan);
    $error .= ", but a plan was already set" . $self->_plan_location($existing_plan);

    die "$error.\n";
}


sub _plan_location {
    my $self = shift;
    my $plan = shift;

    my $file = $plan->file;
    my $line = $plan->line;

    my $location = '';
    $location .= " at $file"   if defined $file;
    $location .= " line $line" if defined $line;

    return $location;
}


__PACKAGE__->meta->make_immutable();
no TB2::Mouse;
1;
