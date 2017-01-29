package Test2::Formatter::Pretty;

use strict;
use warnings;
require PerlIO;

use if $^O eq 'MSWin32', 'Win32::Console::ANSI';
use Term::Encoding;
use Term::ANSIColor ();
use File::Spec ();

our $VERSION = '0.40';

*colored = -t STDOUT || $ENV{PERL_TEST_PRETTY_ENABLED} ? \&Term::ANSIColor::colored : sub { $_[1] };

my $SHOW_DUMMY_TAP;
my $TERM_ENCODING = Term::Encoding::term_encoding();
my $ENCODING_IS_UTF8 = $TERM_ENCODING =~ /^utf-?8$/i;

our $NO_ENDING;

our $BASE_DIR = Cwd::getcwd();
my %filecache;

# stolen from original Test::Pretty code
my $get_src_line = sub {
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

use Test2::Util::HashBase qw{ no_numbers handles _encoding };

use Carp qw/croak/;
use Cwd ();

BEGIN {
    require Test2::Formatter;
    our @ISA = qw(Test2::Formatter::TAP);
    
    *OUT_STD = Test2::Formatter::TAP->can('OUT_STD');
    *OUT_ERR = Test2::Formatter::TAP->can('OUT_ERR');

    my $todo = OUT_ERR() + 1;
    *OUT_TODO = sub() { $todo };
}

our %CONVERTERS = (
    'Test2::Event::Ok'                      => 'event_ok',
    'Test2::Event::Skip'                    => 'event_skip',
    'Test2::Event::Note'                    => 'event_note',
    'Test2::Event::Diag'                    => 'event_diag',
    'Test2::Event::Bail'                    => 'event_bail',
    'Test2::Event::Exception'               => 'event_exception',
    'Test2::Event::Subtest'                 => 'event_subtest',
    'Test2::Event::Plan'                    => 'event_plan',
    'Test2::Event::TAP::Version'            => 'event_version',
    'Test2::Formatter::Pretty::TodoDiag'    => 'event_todo_diag',
);

if ($ENV{HARNESS_ACTIVE}) {
    $SHOW_DUMMY_TAP++;
}

my %SAFE_TO_ACCESS_HASH = %CONVERTERS;

_autoflush(\*STDOUT);
_autoflush(\*STDERR);

sub init {
    my $self = shift;

    $self->{+HANDLES} ||= $self->_open_handles;
    my $handles = $self->{+HANDLES};
    binmode($_, ":encoding($TERM_ENCODING)") for @$handles;
    $self->{+_ENCODING} = $TERM_ENCODING;

    $self->{+HANDLES}->[OUT_TODO] = $self->{+HANDLES}->[OUT_STD];
}

if ($^C) {
    no warnings 'redefine';
    *write = sub {};
}

sub _autoflush {
    my($fh) = pop;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;
}

sub event_ok {
    my $self = shift;
    my ($e, $num) = @_;

    # The OK event of subtest is not displayed.
    return [OUT_STD, ""] if ($e->subtest_id and $e->{pass});

    my ($name, $todo) = @{$e}{qw/name todo/};
    my $in_todo = defined($todo);

    my $filename = $e->trace->file;
    my $line = $e->trace->line;
    my $src_line;

    if (defined($line)) {
        $src_line = $get_src_line->($filename, $line);
    } else {
        $src_line = '';
    }

    my $out = "";

    if (! $e->{pass} ) {
        my $fail_char = $ENCODING_IS_UTF8 ? "\x{2716}" : "x";
        $out .= colored(['red'], $fail_char);
    } else {
        my $success_char = $ENCODING_IS_UTF8 ? "\x{2713}" : "o";
        $out .= colored(['green'], $success_char);
    }

    my @extra;
    defined($name) && (
        (index($name, "\n") != -1 && (($name, @extra) = split(/\n\r?/, $name, -1))),
        ((index($name, "#" ) != -1  || substr($name, -1) eq '\\') && (($name =~ s|\\|\\\\|g), ($name =~ s|#|\\#|g)))
    );

    my $space = @extra ? ' ' x (length($out) + 2) : '';

    $name ||= "  L$line: $src_line";

    if (defined $name) {
        $name =~ s|#|\\#|g;
        $out .= colored([$ENV{TEST_PRETTY_COLOR_NAME} || 'BRIGHT_BLACK'], "  $name");
    }

    $out .= " # TODO" if $in_todo;
    $out .= " $todo" if defined($todo) && length($todo);

    return([OUT_STD, "$out\n"]) unless @extra;

    return $self->event_ok_multiline($out, $space, @extra);
}

sub event_skip {
    my $self = shift;
    my ($e, $num) = @_;

    my $name   = $e->name;
    my $reason = $e->reason;
    my $todo   = $e->todo;

    my $out = "";
    $out .= "not " unless $e->{pass};
    $out .= "ok";
    $out .= " $num" if defined $num;
    $out .= " - $name" if $name;
    if (defined($todo)) {
        $out .= " # TODO & SKIP"
    }
    else {
        $out = colored(['yellow'], "skip")
    }
    $out .= " $reason" if defined($reason) && length($reason);

    return([OUT_STD, "$out\n"]);
}

sub event_note {
    my $self = shift;
    my ($e, $num) = @_;

    chomp(my $msg = $e->message);
    # It does not display the string 'Subtest'
    # ... It's a bit miscellaneous implementation
    unless ($msg =~ s/^Subtest: /  /) {
        $msg =~ s/^/# /;
        $msg =~ s/\n/\n# /g;
    }

    return [OUT_STD, "$msg\n"];
}

sub event_plan {
    my $self = shift;
    my ($e, $num) = @_;

    my $directive = $e->directive;
    return if $directive && $directive eq 'NO PLAN';
	return if $e->max != 0; # display only skip all

    $SHOW_DUMMY_TAP = 0;

    my $reason = $e->reason;
    $reason =~ s/\n/\n# /g if $reason;

    my $plan = "1.." . $e->max;
    if ($directive) {
        $plan .= " # $directive";
        $plan .= " $reason" if defined $reason;
    }

    return [OUT_STD, "$plan\n"];
}

sub event_todo_diag {
    my $self = shift;
    my @out = $self->event_diag(@_);
    $out[0]->[0] = OUT_TODO();
    return @out;
}

sub finalize {
    my $self = shift;

    my ($plan, $count, $failed) = @_;

    if ($SHOW_DUMMY_TAP) {
        my $msg = 'ok';
        if ($failed or $plan != $count) {
            $msg = 'not ' . $msg;
        }
            
        my $handles = $self->{+HANDLES};
        my $io = $handles->[OUT_STD()];
        print $io "\n$msg\n";
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Test2::Formatter::Pretty;

=cut
