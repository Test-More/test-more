use Test2::Bundle::Extended;
use Test2::Tools::Spec;
use Test2::Util  qw/CAN_REALLY_FORK CAN_THREAD/;

my $runner_class;

# These 2 always run
case default => sub { $runner_class = 'Test2::Workflow::Runner' };
case NoIso   => sub { $runner_class = 'Test2::Workflow::Runner::Isolate::NoIso' };

# Only check if the current perl has true forking
case Fork => sub { $runner_class = 'Test2::Workflow::Runner::Isolate::Fork' }
    if CAN_REALLY_FORK;

# Only check if the current perl can thread, and has a sufficient threads version.
case Threads => sub { $runner_class = 'Test2::Workflow::Runner::Isolate::Threads' }
    if CAN_THREAD && eval { require threads; threads->VERSION('1.34'); 1 };

mini verify => sub {
    my $runner_file = $runner_class;
    $runner_file =~ s{::}{/}g;
    $runner_file .= ".pm";
    require $runner_file;
    my $runner = $runner_class->instance(rand => 0);

    my $spec = describe 'outer' => sub {
        before_all 'root_before_all'   => sub { note "root_before_all" };
        after_all 'root_after_all'     => sub { note 'root_after_all' };
        before_each 'root_before_each' => sub { note 'root_before_each' };
        after_each 'root_after_each'   => sub { note 'root_after_each' };

        around_all 'root_around_all' => sub {
            note 'root_around_all_prefix';
            $_[0]->();
            note 'root_around_all_postfix';
        };

        around_each 'root_around_each' => sub {
            note 'root_around_each_prefix';
            $_[0]->();
            note 'root_around_each_postfix';
        };

        case root_x => sub { note 'root case x' };
        case root_y => sub { note 'root case y' };

        tests 'root_a' => sub { ok(1, 'root_a') };
        tests 'root_b' => sub { ok(1, 'root_b') };

        tests 'root_long' => sub {
            ok(1, 'root_long_1');

            ok(1, 'root_long_2');
        };

        tests dup_name => sub { ok(1, 'dup_name') };

        describe nested => sub {
            before_all 'nested_before_all'   => sub { note "nested_before_all" };
            after_all 'nested_after_all'     => sub { note 'nested_after_all' };
            before_each 'nested_before_each' => sub { note 'nested_before_each' };
            after_each 'nested_after_each'   => sub { note 'nested_after_each' };

            around_all 'nested_around_all' => sub {
                note 'nested_around_all_prefix';
                $_[0]->();
                note 'nested_around_all_postfix';
            };

            around_each 'nested_around_each' => sub {
                note 'nested_around_each_prefix';
                $_[0]->();
                note 'nested_around_each_postfix';
            };

            case nested_x => sub { note 'nested case x' };
            case nested_y => sub { note 'nested case y' };

            tests 'nested_a' => sub { ok(1, 'nested_a') };
            tests 'nested_b' => sub { ok(1, 'nested_b') };

            tests 'nested_long' => sub {
                ok(1, 'nested_long_1');

                ok(1, 'nested_long_2');
            };

            tests dup_name => sub { ok(1, 'dup_name') };
        };
    };
    $spec->do_post;

    my $events = intercept {
        $runner->run(
            unit     => $spec,
            args     => [],
            no_final => 1,
        );
    };

    is(
        $events,
        array {
            filter_items {
                grep { !$_->isa('Test2::Event::Stamp') } @_
            };
            event Note => {message => 'root_before_all'};
            event Note => {message => 'root_around_all_prefix'};

            event Subtest => sub {
                call name      => "root_$_";
                call pass      => T;
                call subevents => array {
                    filter_items {
                        grep { !$_->isa('Test2::Event::Stamp') } @_
                    };
                    event Note => {message => "root case $_"};

                    event Subtest => sub {
                        call name      => 'root_a';
                        call subevents => array {
                            filter_items {
                                grep { !$_->isa('Test2::Event::Stamp') } @_
                            };
                            event Note => {message => 'root_before_each'};
                            event Note => {message => 'root_around_each_prefix'};
                            event Ok   => {name    => 'root_a', pass => 1};
                            event Note => {message => 'root_after_each'};
                            event Note => {message => 'root_around_each_postfix'};
                            event Plan => {max     => 1};
                            end;
                        };
                    };

                    event Subtest => sub {
                        call name      => 'root_b';
                        call subevents => array {
                            filter_items {
                                grep { !$_->isa('Test2::Event::Stamp') } @_
                            };
                            event Note => {message => 'root_before_each'};
                            event Note => {message => 'root_around_each_prefix'};
                            event Ok   => {name    => 'root_b', pass => 1};
                            event Note => {message => 'root_after_each'};
                            event Note => {message => 'root_around_each_postfix'};
                            event Plan => {max     => 1};
                            end;
                        };
                    };

                    event Subtest => sub {
                        call name      => 'root_long';
                        call subevents => array {
                            filter_items {
                                grep { !$_->isa('Test2::Event::Stamp') } @_
                            };
                            event Note => {message => 'root_before_each'};
                            event Note => {message => 'root_around_each_prefix'};
                            event Ok   => {name    => 'root_long_1', pass => 1};
                            event Ok   => {name    => 'root_long_2', pass => 1};
                            event Note => {message => 'root_after_each'};
                            event Note => {message => 'root_around_each_postfix'};
                            event Plan => {max     => 2};
                            end;
                        };
                    };

                    event Subtest => sub {
                        call name      => 'dup_name';
                        call subevents => array {
                            filter_items {
                                grep { !$_->isa('Test2::Event::Stamp') } @_
                            };
                            event Note => {message => 'root_before_each'};
                            event Note => {message => 'root_around_each_prefix'};
                            event Ok   => {name    => 'dup_name', pass => 1};
                            event Note => {message => 'root_after_each'};
                            event Note => {message => 'root_around_each_postfix'};
                            event Plan => {max     => 1};
                            end;
                        };
                    };

                    event Subtest => sub {
                        call name      => 'nested';
                        call subevents => array {
                            filter_items {
                                grep { !$_->isa('Test2::Event::Stamp') } @_
                            };
                            event Note => {message => 'nested_before_all'};
                            event Note => {message => 'nested_around_all_prefix'};

                            event Subtest => sub {
                                call name      => "nested_$_";
                                call subevents => array {
                                    filter_items {
                                        grep { !$_->isa('Test2::Event::Stamp') } @_
                                    };
                                    event Note => {message => "nested case $_"};

                                    event Subtest => sub {
                                        call name      => 'nested_a';
                                        call subevents => array {
                                            filter_items {
                                                grep { !$_->isa('Test2::Event::Stamp') } @_
                                            };
                                            event Note => {message => 'root_before_each'};
                                            event Note => {message => 'root_around_each_prefix'};
                                            event Note => {message => 'nested_before_each'};
                                            event Note => {message => 'nested_around_each_prefix'};
                                            event Ok   => {name    => 'nested_a', pass => 1};
                                            event Note => {message => 'nested_after_each'};
                                            event Note => {message => 'nested_around_each_postfix'};
                                            event Note => {message => 'root_after_each'};
                                            event Note => {message => 'root_around_each_postfix'};
                                            event Plan => {max     => 1};
                                            end;
                                        };
                                    };

                                    event Subtest => sub {
                                        call name      => 'nested_b';
                                        call subevents => array {
                                            filter_items {
                                                grep { !$_->isa('Test2::Event::Stamp') } @_
                                            };
                                            event Note => {message => 'root_before_each'};
                                            event Note => {message => 'root_around_each_prefix'};
                                            event Note => {message => 'nested_before_each'};
                                            event Note => {message => 'nested_around_each_prefix'};
                                            event Ok   => {name    => 'nested_b', pass => 1};
                                            event Note => {message => 'nested_after_each'};
                                            event Note => {message => 'nested_around_each_postfix'};
                                            event Note => {message => 'root_after_each'};
                                            event Note => {message => 'root_around_each_postfix'};
                                            event Plan => {max     => 1};
                                            end;
                                        };
                                    };

                                    event Subtest => sub {
                                        call name      => 'nested_long';
                                        call subevents => array {
                                            filter_items {
                                                grep { !$_->isa('Test2::Event::Stamp') } @_
                                            };
                                            event Note => {message => 'root_before_each'};
                                            event Note => {message => 'root_around_each_prefix'};
                                            event Note => {message => 'nested_before_each'};
                                            event Note => {message => 'nested_around_each_prefix'};
                                            event Ok   => {name    => 'nested_long_1', pass => 1};
                                            event Ok   => {name    => 'nested_long_2', pass => 1};
                                            event Note => {message => 'nested_after_each'};
                                            event Note => {message => 'nested_around_each_postfix'};
                                            event Note => {message => 'root_after_each'};
                                            event Note => {message => 'root_around_each_postfix'};
                                            event Plan => {max     => 2};
                                            end;
                                        };
                                    };

                                    event Subtest => sub {
                                        call name      => 'dup_name';
                                        call subevents => array {
                                            filter_items {
                                                grep { !$_->isa('Test2::Event::Stamp') } @_
                                            };
                                            event Note => {message => 'root_before_each'};
                                            event Note => {message => 'root_around_each_prefix'};
                                            event Note => {message => 'nested_before_each'};
                                            event Note => {message => 'nested_around_each_prefix'};
                                            event Ok   => {name    => 'dup_name', pass => 1};
                                            event Note => {message => 'nested_after_each'};
                                            event Note => {message => 'nested_around_each_postfix'};
                                            event Note => {message => 'root_after_each'};
                                            event Note => {message => 'root_around_each_postfix'};
                                            event Plan => {max     => 1};
                                            end;
                                        };
                                    };

                                    event Plan => {max => 4};
                                    end;
                                };
                                }
                                for qw/x y/;

                            event Note => {message => 'nested_after_all'};
                            event Note => {message => 'nested_around_all_postfix'};
                            event Plan => {max     => 2};
                        };
                    };

                    event Plan => {max => 5};
                    end;
                };
                }
                for qw/x y/;

            event Note => {message => 'root_after_all'};
            event Note => {message => 'root_around_all_postfix'};
            end;
        },
        "Got expected event structure ($runner_class)"
    );
};

done_testing;
