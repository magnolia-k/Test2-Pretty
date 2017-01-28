use strict;
use warnings;

use utf8;

use Test2::Pretty;
use Test::More tests => 3;

ok(1, "サンプルテスト - 成功");

subtest 'nested test 1' => sub {
    ok(1, 'test1');

    subtest 'nested test 2' => sub {
        ok(1, 'test2');
    };

    ok(1);
};

ok(0, "サンプルテスト - 失敗");

