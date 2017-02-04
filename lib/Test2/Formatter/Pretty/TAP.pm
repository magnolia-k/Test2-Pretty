package Test2::Formatter::Pretty::TAP;

use strict;
use warnings;

use parent qw/Test::Builder::Formatter/;
use Test2::Util::HashBase qw{ handles };

BEGIN {
#    *OUT_STD  = Test::Builder::Formatter->can('OUT_STD');
    *OUT_ERR  = Test::Builder::Formatter->can('OUT_ERR');
#    *OUT_TODO  = Test::Builder::Formatter->can('OUT_TODO');
}

sub finalize {
    my $self = shift;
    my ($plan, $count, undef, undef, $is_subtest) = @_;

    my $handles = $self->{+HANDLES};

    if (!$is_subtest and $plan and ($plan ne 'SKIP') and ($plan != $count)) {
        my $io = $handles->[OUT_ERR()];
        print $io "# Bad plan: $count != $plan\n";
    }
}




1;
