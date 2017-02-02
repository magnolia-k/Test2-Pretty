package Test::Pretty;

use strict;
use warnings;

our $VERSION = '0.40';

require Test::Builder;

# Conditionally load Windows Term encoding
use if $^O eq 'MSWin32', 'Win32::Console::ANSI';
use Term::Encoding ();

use File::Spec ();
use Term::ANSIColor ();
use Test::More ();
use Scope::Guard;
use Carp ();

use Cwd ();

*colored = -t STDOUT || $ENV{PERL_TEST_PRETTY_ENABLED} ? \&Term::ANSIColor::colored : sub { $_[1] };

our $TERM_ENCODING = Term::Encoding::term_encoding();
our $ENCODING_IS_UTF8 = $TERM_ENCODING =~ /^utf-?8$/i;

our $BASE_DIR = Cwd::getcwd();
my %filecache;
our $get_src_line = sub {
    my ($filename, $lineno) = @_;
    $filename = File::Spec->rel2abs($filename, $BASE_DIR);
    # read a source as utf-8... Yes. it's bad. but works for most of users.
    # I may need to remove binmode for STDOUT?
    my $lines = $filecache{$filename} ||= sub {
        # :encoding is likely to override $@
        local $@;
        open my $fh, "<:encoding(utf-8)", $filename
            or return '';
        [<$fh>]
    }->();
    return unless ref $lines eq 'ARRAY';
    my $line = $lines->[$lineno-1];
    $line =~ s/^\s+|\s+$//g;
    return $line;
};

if (Test::Builder->VERSION > 1.3) {

    my $builder = Test::Builder->new();
    my $hub = $builder->{Stack}->top;

    if ((!$ENV{HARNESS_ACTIVE} || $ENV{PERL_TEST_PRETTY_ENABLED})) {
        require Test2::Formatter::Pretty;
        $hub->format(Test2::Formatter::Pretty->new());
    } else {
        no warnings 'redefine';
        my $ORIGINAL_ok = \&Test::Builder::ok;
        my @NAMES;

        $|++;

        my ($arrow_mark, $failed_mark);
        if ($ENCODING_IS_UTF8) {
            $arrow_mark = "\x{bb}";
            $failed_mark = " \x{2192} ";
        } else {
            $arrow_mark = ">>";
            $failed_mark = " x ";
        }

        my $builder = Test::Builder->new();
        my $hub = $builder->{Stack}->top;
        my $formatter = Test::Builder::Formatter->new();
        $formatter->encoding($TERM_ENCODING);
        $hub->format($formatter);

        *Test::Builder::subtest = sub {
            push @NAMES, $_[1];
            my $guard = Scope::Guard->new(sub {
                pop @NAMES;
            });
            $_[0]->note(
                colored(['cyan'], $arrow_mark x (@NAMES*2)) . 
                    " " . join(colored(['yellow'], $failed_mark), $NAMES[-1])
                );
            $_[2]->();
        };

        *Test::Builder::ok = sub {
            my @args = @_;
            $args[2] ||= do {
                my ( $package, $filename, $line ) = caller($Test::Builder::Level);
                "L $line: " . $get_src_line->($filename, $line);
            };
            if (@NAMES) {
                $args[2] = "(" . join( '/', @NAMES)  . ") " . $args[2];
            }
            local $Test::Builder::Level = $Test::Builder::Level + 1;
            &$ORIGINAL_ok(@_);
        }
    }
} else {
    require Test::Pretty::Originator;
}

1;

__END__

=encoding utf8

=for stopwords cho45++

=head1 NAME

Test::Pretty - Smile Precure!

=head1 SYNOPSIS

  use Test::Pretty;

=head1 DESCRIPTION

Test::Pretty is a prettifier for Test::More.

When you are writing a test case such as following:

    use strict;
    use warnings;
    use utf8;
    use Test::More;

    subtest 'MessageFilter' => sub {
        my $filter = MessageFilter->new('foo');

        subtest 'should detect message with NG word' => sub {
            ok($filter->detect('hello from foo'));
        };
        subtest 'should not detect message without NG word' => sub {
            ok(!$filter->detect('hello world!'));
        };
    };

    done_testing;

This code outputs following result:

=begin html

<div><img src="https://raw.github.com/tokuhirom/Test-Pretty/master/img/more.png"></div>

=end html

No, it's not readable. Test::Pretty makes this result to pretty.

You can enable Test::Pretty by

    use Test::Pretty;

Or just add following option to perl interpreter.
    
    -MTest::Pretty

After this, you can get a following pretty output.

=begin html

<div><img src="https://raw.github.com/tokuhirom/Test-Pretty/master/img/pretty.png"></div>

=end html

And this module outputs TAP when $ENV{HARNESS_ACTIVE} is true or under the win32.

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom AAJKLFJEF@ GMAIL COME<gt>

=head1 THANKS TO

Some code was taken from L<Test::Name::FromLine>, thanks cho45++

=head1 SEE ALSO

L<Acme::PrettyCure>

=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
