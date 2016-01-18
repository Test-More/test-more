use strict;
use warnings;

use Test2::Bundle::Extended -target => 'Test2::Workflow::Util';
use Test2::Util::Sub qw/sub_name/;
use Test2::Workflow::Util qw/CAN_SET_SUB_NAME set_sub_name rename_anon_sub update_mask/;

imported_ok qw/ CAN_SET_SUB_NAME set_sub_name rename_anon_sub update_mask /;

sub xxx { 'xxx' }

if (CAN_SET_SUB_NAME) {
    my $sub = sub { 1 };
    like(sub_name($sub), qr/__ANON__$/, "Got sub name (anon)");
    set_sub_name('foo', $sub);
    like(sub_name($sub), qr/foo$/, "Got new sub name");

    $sub = sub { 2 };
    like(sub_name($sub), qr/__ANON__$/, "Got sub name (anon)");
    rename_anon_sub('bar', $sub);
    like(sub_name($sub), qr/bar$/, "Got new sub name");

    $sub = \&xxx;
    like(sub_name($sub), qr/xxx/, "sub is named");
    rename_anon_sub('bar', $sub);
    like(sub_name($sub), qr/xxx/, "sub is not renamed");
}

done_testing;
