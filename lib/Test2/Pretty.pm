package Test2::Pretty;
use 5.008001;
use strict;
use warnings;

our $VERSION = "v0.0.1";

use Test2::API qw/test2_formatter_set/;

require Test2::Formatter::Pretty;
test2_formatter_set('Test2::Formatter::Pretty');

1;
__END__

=encoding utf-8

=head1 NAME

Test2::Pretty - It's new $module

=head1 SYNOPSIS

    use Test2::Pretty;

=head1 DESCRIPTION

Test2::Pretty is ...

=head1 LICENSE

Copyright (C) Magnolia K.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Magnolia K E<lt>magnolia.k@icloud.comE<gt>

=cut

