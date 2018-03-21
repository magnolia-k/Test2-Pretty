package Test2::Formatter::Pretty;

use strict;
use warnings;

use utf8;

our $VERSION = 'v0.0.1';

use parent qw/Test2::Formatter/;
use Test2::API qw/context/;
use Test2::Util::HashBase qw{
    handles _encoding _last_fh no_numbers
    -made_assertion
};

use Test2::Util qw/clone_io/;

use File::Spec ();
use Term::ANSIColor ();
use Term::Encoding ();

sub OUT_STD() { 0 }
sub OUT_ERR() { 1 }

sub _autoflush {
    my($fh) = pop;
    my $old_fh = select $fh;
    $| = 1;
    select $old_fh;
}

_autoflush(\*STDOUT);
_autoflush(\*STDERR);

sub _open_handles {
    my $self = shift;

    require Test2::API;
    my $out = clone_io(Test2::API::test2_stdout());
    my $err = clone_io(Test2::API::test2_stderr());

    _autoflush($out);
    _autoflush($err);

    return [$out, $err];
}

*colored = -t STDOUT || $ENV{PERL_TEST_PRETTY_ENABLED} ? \&Term::ANSIColor::colored : sub { $_[1] };

our $BASE_DIR = Cwd::getcwd();
my %filecache;
# For use in string interpolation, it is defined as a function object, not as a function.
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

my $SHOW_DUMMY_TAP;
my $TERM_ENCODING = Term::Encoding::term_encoding();
my $ENCODING_IS_UTF8 = $TERM_ENCODING =~ /^utf-?8$/i;
my $SKIP_SUBTEST_INFO = undef;

sub init {
    my $self = shift;

    delete $self->{encoding};
    $self->{+HANDLES} ||= $self->_open_handles;
    binmode($_, "encoding($TERM_ENCODING)") for @{$self->{+HANDLES}};

    $self->{+_ENCODING} = $TERM_ENCODING;

    if ($ENV{HARNESS_ACTIVE}) {
        $SHOW_DUMMY_TAP++;
    }
}

sub hide_buffered { 0 }

sub write {
    my ($self, $e, $num, $f) = @_;

    $f ||= $e->facet_data;

    my @tap = $self->event_tap($f, $num) or return;
    $self->{+MADE_ASSERTION} = 1 if $f->{assert};

    my $nesting = $f->{trace}->{nested} || 0;
    my $indent = '    ' x ($nesting + 1);
    my $handles = $self->{+HANDLES};

    for my $set (@tap) {
        no warnings 'uninitialized';
        my ($hid, $msg) = @$set;
        next unless $msg;
        my $io = $handles->[$hid] or next;
 
        print $io "\n"
            if $ENV{HARNESS_ACTIVE}
            && !$ENV{HARNESS_IS_VERBOSE}
            && $hid == OUT_ERR
            && $self->{+_LAST_FH} != $io
            && $msg =~ m/^#\s*Failed test /;

        # In Pretty mode, indent all. Because Test::Harness ignores the indented output
        $msg =~ s/^/$indent/mg;
        print $io $msg;
        $self->{+_LAST_FH} = $io;
    }
}

sub event_tap {
    my ($self, $f, $num) = @_;
 
    my @tap;

    push @tap => $self->plan_tap($f) if !$f->{parent} && $f->{plan} && !$self->{+MADE_ASSERTION};

    if ($f->{assert}) {
        if (!$f->{parent}) {
            push @tap => $self->assert_tap($f, $num);
            push @tap => $self->debug_tap($f, $num) unless $f->{assert}->{no_debug} || $f->{assert}->{pass};
        } else {
            # Since the assertion result of subtest itself is redundant, it is not displayed.
            # Set only the flag to skip the message when the subtest fails.
            $SKIP_SUBTEST_INFO++;
        }
    }
 
    push @tap => $self->error_tap($f) if $f->{errors};
    push @tap => $self->info_tap($f) if $f->{info};
    push @tap => $self->plan_tap($f) if !$f->{parent} && $self->{+MADE_ASSERTION} && $f->{plan};
    push @tap => $self->halt_tap($f) if $f->{control}->{halt};
 
    return @tap if @tap;
    return @tap if $f->{control}->{halt};
    return @tap if grep { $f->{$_} } qw/assert plan info errors/;
 
    return $self->summary_tap($f, $num);
}

sub error_tap {
    my $self = shift;
    my ($f) = @_;
 
    my $IO = ($f->{amnesty} && @{$f->{amnesty}}) ? OUT_STD : OUT_ERR;
 
    return map {
        my $details = $_->{details};
 
        my $msg;
        if (ref($details)) {
            require Data::Dumper;
            my $dumper = Data::Dumper->new([$details])->Indent(2)->Terse(1)->Pad('# ')->Useqq(1)->Sortkeys(1);
            chomp($msg = $dumper->Dump);
        }
        else {
            chomp($msg = $details);
            $msg =~ s/^/# /;
            $msg =~ s/\n/\n# /g;
        }
 
        [$IO, "$msg\n"];
    } @{$f->{errors}};
}
 

sub plan_tap {
    my $self = shift;
    my ($f) = @_;
    my $plan = $f->{plan} or return;

    return if $plan->{none};

    if ($plan->{skip}) {
        my $reason = $plan->{details} or return [OUT_STD, "1..0 # SKIP\n"];
        chomp($reason);
        return [OUT_STD, '1..0 # SKIP ' . $reason . "\n"];
    }

    return;
}

sub no_subtest_space { 0 }
sub assert_tap {
    my $self = shift;
    my ($f, $num) = @_;

    my $assert = $f->{assert};
    my $pass = $assert->{pass};
    my $name = $assert->{details};

    my $ok = '';
    if ($pass) {
        my $success_char = $ENCODING_IS_UTF8 ? "\x{2713}" : "o";
        $ok .= colored(['green'], $success_char);
    } else {
        my $fail_char = $ENCODING_IS_UTF8 ? "\x{2716}" : "x";
        $ok .= colored(['red'], $fail_char);
    }

    my @extra;

    defined($name) && (
        (index($name, "\n") != -1 && (($name, @extra) = split(/\n\r?/, $name, -1))),
        ((index($name, "#" ) != -1  || substr($name, -1) eq '\\') && (($name =~ s|\\|\\\\|g), ($name =~ s|#|\\#|g)))
    );

    if (!defined($name)) {
        my ($pkg, $file, $line) = @{$f->{trace}{frame}};
        my $src_line = $get_src_line->($file, $line);
        $name ||= "  L$line: $src_line";
    }

    my $extra_space = @extra ? ' ' x (length($ok) + 2) : '';
    my $extra_indent = '';

    my ($directives, $reason, $is_skip);
    if ($f->{amnesty}) {
        my %directives;

        for my $am (@{$f->{amnesty}}) {
            next if $am->{inherited};
            my $tag = $am->{tag} or next;
            $is_skip = 1 if $tag eq 'skip';

            $directives{$tag} ||= $am->{details};
        }

        my %seen;
        my @order = grep { !$seen{$_}++ } sort keys %directives;

        $directives = ' # ' . join ' & ' => @order;

        for my $tag ('skip', @order) {
            next unless defined($directives{$tag}) && length($directives{$tag});
            $reason = $directives{$tag};
            last;
        }
    }

    if (defined $name) {
        $name = colored([$ENV{TEST_PRETTY_COLOR_NAME} || 'BRIGHT_BLACK'], "  $name");
    }

    $ok .= " $name" if defined $name && !($is_skip && !$name);

    if ($directives) {
        $directives = ' # TODO & SKIP' if $directives eq ' # TODO & skip';
        $directives = colored([$ENV{TEST_PRETTY_COLOR_NAME} || 'BRIGHT_BLACK'], $directives);
        $ok .= $directives;
        if (defined($reason)) {
            $reason = colored([$ENV{TEST_PRETTY_COLOR_NAME} || 'BRIGHT_BLACK'], $reason);
            $ok .= " $reason";
        }
    }

    $extra_space = ' ' if $self->no_subtest_space;

    my @out = ([OUT_STD, "$ok\n"]);
    push @out => map {[OUT_STD, "${extra_indent}#${extra_space}$_\n"]} @extra if @extra;

    return @out;
}

sub debug_tap {
    my ($self, $f, $num) = @_;

    # Figure out the debug info, this is typically the file name and line
    # number, but can also be a custom message. If no trace object is provided
    # then we have nothing useful to display.
    my $name  = $f->{assert}->{details};
    my $trace = $f->{trace};

    my $debug = "[No trace info available]";
    if ($trace->{details}) {
        $debug = $trace->{details};
    }
    elsif ($trace->{frame}) {
        my ($pkg, $file, $line) = @{$trace->{frame}};
        $debug = "at $file line $line." if $file && $line;
    }

    my $amnesty = $f->{amnesty} && @{$f->{amnesty}}
        ? ' (with amnesty)'
        : '';

    # Create the initial diagnostics. If the test has a name we put the debug
    # info on a second line, this behavior is inherited from Test::Builder.
    my $msg = defined($name)
        ? qq[# Failed test${amnesty} '$name'\n# $debug\n]
        : qq[# Failed test${amnesty} $debug\n];

    my $IO = $f->{amnesty} && @{$f->{amnesty}} ? OUT_STD : OUT_ERR;

    return [$IO, $msg];
}

sub halt_tap {
    my ($self, $f) = @_;

    return if $f->{trace}->{nested} && !$f->{trace}->{buffered};
    my $details = $f->{control}->{details};

    return [OUT_STD, "Bail out!\n"] unless defined($details) && length($details);
    return [OUT_STD, "Bail out!  $details\n"];
}

sub info_tap {
    my ($self, $f) = @_;

    return map {
        my $details = $_->{details};

        my $IO = $_->{debug} && !($f->{amnesty} && @{$f->{amnesty}}) ? OUT_ERR : OUT_STD;

        my $msg;
        if (ref($details)) {
            require Data::Dumper;
            my $dumper = Data::Dumper->new([$details])->Indent(2)->Terse(1)->Pad('# ')->Useqq(1)->Sortkeys(1);
            chomp($msg = $dumper->Dump);
        }
        else {
            chomp($msg = $details);
            $msg =~ s/^/# /;
            $msg =~ s/\n/\n# /g;
        }

        # あまり良くないコードだけど…
        $msg =~ s/^# Subtest: //;

        my @out = [$IO, "$msg\n"];

        if ($SKIP_SUBTEST_INFO && $msg =~ m/^#   Failed test/) {
            $SKIP_SUBTEST_INFO = undef;
            @out = [$IO, undef];
        }

        if ($msg =~ m/^# Looks like you failed/) {
            @out = [$IO, undef];
        }

        @out;
    } @{$f->{info}};
}

sub summary_tap {
    my ($self, $f, $num) = @_;

    return if $f->{about}->{no_display};

    my $summary = $f->{about}->{details} or return;
    chomp($summary);
    $summary =~ s/^/# /smg;

    return [OUT_STD, "$summary\n"];
}

sub finalize {
    my $self = shift;
    my (undef, undef, undef, $pass, $is_subtest) = @_;

    if ($SHOW_DUMMY_TAP && (! $is_subtest)) {
        print "1..1\n";
        if ($pass) {
            print "ok\n";
        } else {
            print "not ok\n";
        }
    }
}

1;

__END__
