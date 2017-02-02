# Name

Test2::Pretty - prototype Test::Pretty for new Test2 lib!

# SYNOPSIS

```sh
$ cd Test2-Pretty
$ carton install
$ carton exec perl -Ilib -MTest::Pretty example/01-success.test
```

to compare original Test::Pretty's output

```sh
$ cpanm Test::Pretty
$ perl -MTest::Pretty example/01-success.test
```

**During experiment of implementation!!!!**

# DESCRIPTION

```perl
use strict;
use warnings;
use utf8;
use Test2::Pretty;
use Test::More;

subtest 'test case1' => sub {
    ok(1, "subtest 1");
};

ok(1, "test2");

done_testing;
```
