package Test2::Formatter::Pretty;

use strict;
use warnings;

our $VERSION = '0.40';

use parent qw/Test::Builder::Formatter/;
use Test2::Util::HashBase qw{ handles _encoding };

BEGIN {
    *OUT_STD  = Test::Builder::Formatter->can('OUT_STD');
    *OUT_ERR  = Test::Builder::Formatter->can('OUT_ERR');
    *OUT_TODO  = Test::Builder::Formatter->can('OUT_TODO');
}

# Conditionally load Windows Term encoding
use if $^O eq 'MSWin32', 'Win32::Console::ANSI';
use Term::Encoding ();
use Term::ANSIColor ();
use File::Spec ();
use Cwd ();

*colored = -t STDOUT || $ENV{PERL_TEST_PRETTY_ENABLED} ? \&Term::ANSIColor::colored : sub { $_[1] };

our $BASE_DIR = Cwd::getcwd();
my %filecache;
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

sub get_src_line {
    return $get_src_line;
}

my $TERM_ENCODING  = Term::Encoding::term_encoding();
my $SHOW_DUMMY_TAP = $ENV{HARNESS_ACTIVE} ? 1 : 0; 

sub event_ok {
    my $self = shift;
    my ($e, $num) = @_;

    # The OK event of subtest is not displayed.
    return [OUT_STD, ""] if ($e->subtest_id and $e->{pass});

    my ($name, $todo) = @{$e}{qw/name todo/};
    my $in_todo  = defined($todo);
    my $line     = $e->trace->line;
    my $src_line = $get_src_line->($e->trace->file, $line);

    my $out = "";

    my $encoding_is_utf8 = $TERM_ENCODING =~ /^utf-?8$/i;

    if (! $e->{pass} ) {
        my $fail_char = $encoding_is_utf8 ? "\x{2716}" : "x";
        $out .= colored(['red'], $fail_char);
    } else {
        my $success_char = $encoding_is_utf8 ? "\x{2713}" : "o";
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

sub event_diag {
    my $self = shift;
    my ($e, $num) = @_;

    chomp(my $msg = $e->message);
    # It does not display about plan warning...
    # ... It's a bit miscellaneous implementation
	if (! $e->in_subtest and $msg =~ /^Looks like you planned/ ) {
        return [OUT_ERR, ""];
    }

    $msg =~ s/^/# /;
    $msg =~ s/\n/\n# /g;

    return [OUT_ERR, "$msg\n"];
}

sub event_plan {
    my $self = shift;
    my ($e) = @_;

	return if $e->max != 0; # display only skip all

    my $directive = $e->directive;
    my $reason = $e->reason;
    $reason =~ s/\n/\n# /g if $reason;

    my $plan = "1..0";
    if ($directive) {
        $plan .= " # $directive";
        $plan .= " $reason" if defined $reason;
    }

    return [OUT_STD, "$plan\n"];
}

sub finalize {
    my $self = shift;
    my ($plan, $count, $failed, undef, $is_subtest) = @_;

    my $handles = $self->{+HANDLES};

    if (!$is_subtest and $plan and ($plan ne 'SKIP') and ($plan != $count)) {
        my $io = $handles->[OUT_ERR()];
        print $io "# Bad plan: $count != $plan\n";
    }

    if (!$is_subtest and $SHOW_DUMMY_TAP and $plan ne 'SKIP') {
        my $msg = 'ok';
        if ($failed or !$plan or $plan != $count) {
            $msg = 'not ' . $msg;
        }

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
