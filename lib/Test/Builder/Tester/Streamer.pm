package Test::Builder::Tester::Streamer;

use TB2::Mouse;
extends 'TB2::Streamer::Debug';

# Test::Builder::Tester helper class to capture and test output

sub expect {
    my $self = shift;
    my $name = shift;

    my @checks = @_;
    foreach my $check (@checks) {
        $check = $self->_translate_Failed_check($check);
        push @{ $self->wanted->{$name} }, ref $check ? $check : "$check\n";
    }
}

sub _translate_Failed_check {
    my( $self, $check ) = @_;

    if( $check =~ /\A(.*)#     (Failed .*test) \((.*?) at line (\d+)\)\Z(?!\n)/ ) {
        $check = "/\Q$1\E#\\s+\Q$2\E.*?\\n?.*?\Qat $3\E line \Q$4\E.*\\n?/";
    }

    return $check;
}

##
# return true iff the expected data matches the got data

sub check {
    my $self = shift;
    my $name = shift;

    # turn off warnings as these might be undef
    local $^W = 0;

    my @checks = @{ $self->wanted->{$name} };
    my $got    = $self->read($name);
    foreach my $check (@checks) {
        $check = "\Q$check\E" unless( $check =~ s,^/(.*)/$,$1, or ref $check );
        return 0 unless $got =~ s/^$check//;
    }

    return length $got == 0;
}

##
# a complaint message about the inputs not matching (to be
# used for debugging messages)

has 'name2handle' =>
  is            => 'ro',
  isa           => 'HashRef',
  default       => sub {
      return {
          out       => 'STDOUT',
          err       => 'STDERR'
      }
  };

sub complaint {
    my $self   = shift;
    my $name   = shift;
    my $type   = $self->name2handle->{$name};
    my $got    = $self->output_for($name);
    my $wanted = join "\n", @{ $self->wanted->{$name} };

    # are we running in colour mode?
    if(Test::Builder::Tester::color()) {
        # get color
        eval { require Term::ANSIColor };
        unless($@) {
            # colours

            my $green = Term::ANSIColor::color("black") . Term::ANSIColor::color("on_green");
            my $red   = Term::ANSIColor::color("black") . Term::ANSIColor::color("on_red");
            my $reset = Term::ANSIColor::color("reset");

            # work out where the two strings start to differ
            my $char = 0;
            $char++ while substr( $got, $char, 1 ) eq substr( $wanted, $char, 1 );

            # get the start string and the two end strings
            my $start = $green . substr( $wanted, 0, $char );
            my $gotend    = $red . substr( $got,    $char ) . $reset;
            my $wantedend = $red . substr( $wanted, $char ) . $reset;

            # make the start turn green on and off
            $start =~ s/\n/$reset\n$green/g;

            # make the ends turn red on and off
            $gotend    =~ s/\n/$reset\n$red/g;
            $wantedend =~ s/\n/$reset\n$red/g;

            # rebuild the strings
            $got    = $start . $gotend;
            $wanted = $start . $wantedend;
        }
    }

    return "$type is:\n" . "$got\nnot:\n$wanted\nas expected";
}

##
# forget all expected and got data

has 'wanted' =>
  is            => 'rw',
  isa           => 'HashRef',
  default       => sub {
      return {
          out   => [],
          err   => [],
      }
  }
;

sub clear {
    my $self = shift;

    $self->SUPER::clear;
    %{$self->wanted} = ( out => [], err => [] );
    return;
}

1;
