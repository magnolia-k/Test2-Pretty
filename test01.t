use Test2::Pretty;
use Test::More;

use strict;
use warnings;

use utf8;

subtest 'サブテク入りたい' => sub {
    ok(1, "サブテク入れた");
    ok(0, "サブテク入れなかった");
};

done_testing;
