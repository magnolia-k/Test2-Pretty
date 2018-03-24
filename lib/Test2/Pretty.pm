package Test2::Pretty;
use 5.008001;
use strict;
use warnings;

our $VERSION = "v0.0.1";

use Test2::API qw/test2_formatter_set/;

require Test2::Formatter::Pretty;

if (!$ENV{HARNESS_ACTIVE}) {
    test2_formatter_set('Test2::Formatter::Pretty');
}

1;
__END__

=encoding utf-8

=head1 NAME

Test2::Pretty - Make the test results more visible

=head1 SYNOPSIS

    use Test2::Pretty;
    use Test::More;

    ok(1);
    ok(0);

=head1 DESCRIPTION

It is Test2 API compatible version of Test::Pretty.

The original version of Test::Pretty was made by tokuhirom.

=head1 LICENSE

Copyright (C) Magnolia K.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Magnolia K E<lt>magnolia.k@icloud.comE<gt>

=cut

