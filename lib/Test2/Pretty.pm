use strict;
use warnings;

our $VERSION = '0.40';

use Test::Builder;
use Term::Encoding;

# Is this implementation method correct?
my $builder = Test::Builder->new();
my $hub = $builder->{Stack}->top;

if ((!$ENV{HARNESS_ACTIVE} || $ENV{PERL_TEST_PRETTY_ENABLED})) {
    require Test2::Formatter::Pretty;
    $hub->format(Test2::Formatter::Pretty->new());
} else {
    require Test2::Formatter::TAP;
    $hub->format(Test2::Formatter::TAP->new());

    my $enc = Term::Encoding::term_encoding();
    binmode $builder->output,         ":encoding($enc)";
    binmode $builder->failure_output, ":encoding($enc)";
}

1;

=pod

=encoding UTF-8

=head1 NAME

Test2::Pretty - Make test pretty

=cut
