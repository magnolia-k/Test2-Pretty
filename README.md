# Name

Test2::Pretty - prototype Test::Pretty for new Test2 lib!

# SYNOPSIS

```sh
$ cd Test2-Pretty
$ carton install
$ carton exec T2_FORMATTER='Pretty' perl -Ilib test01.t
```

or

```perl
use Test2::Pretty;
use Test::More;

ok(1);
subtest 'sub test' => sub {
  ok(1);
};
done_testing;
```

**It's still a very experimental implementation**

# LICENSE

Copyright (C) Magnolia K.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

# AUTHOR

Magnolia K <magnolia.k@icloud.com>
