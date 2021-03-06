#!/usr/bin/env perl

# Read the .output file from bison, and construct a table encoding the
# rule/state information for use by the traceback feature.

# $Header$

# COPYRIGHT

while (<>) {
    last if (/^Grammar/);
}

$losubscript = $hisubscript = undef;

$matching_subscript = 0; # for bison 1.875 (1.75 too?) on
while (<>) {
    # Read rules
    if (/^rule\s+([0-9]+)\s+subscript/) {
        $losubscript = $1 unless (defined $losubscript);
        $hisubscript = $1;
    } elsif (/^\s+([0-9]+)\s+[0-9]+\s+subscript/) {
        $losubscript = $1 unless (defined $losubscript);
        $hisubscript = $1;
    } elsif (/^\s+([0-9]+)\s+subscript:/) {
        $losubscript = $1;
        $matching_subscript = 1;
    } elsif ($matching_subscript && /^\s+([0-9]+)\s+\|/) {
        $hisubscript = $1;
    } elsif ($matching_subscript) {
        $matching_subscript = 0;
    }

    if (/^Terminals, with rules/) {
        $_ = <STDIN>;
        last;
    }
}

%codes = (); # tokname -> bison code
$locode = $hicode = undef;

while (<>) {
    chomp;
    last if (/^\s*$/);
    next if (/^\s/);
    next if (/^\$/);

    m{^([^ \t]+)\s+\(([-0-9]+)\)} || die "Unmatched line [$_];";
    $codes{$1} = $2;
    if (!(defined $locode) || ($locode > $2)) { $locode = $2; }
    if (!(defined $hicode) || ($hicode < $2)) { $hicode = $2; }
}

$state = undef;
@toks = (); # state_no -> array of tokens that can be shifted

while (<>) {
    chomp;
    if (/^state ([0-9]+)/) {
        $state = $1;
        next;
    }

    if (/^\s+([^ \t]+)\s+shift, and go to state ([0-9]+)/) {
        $code = $codes{$1};
        if (defined $code) {
            push (@{$toks[$state]}, $codes{$1});
        } else {
            print STDERR "Warning : no code for $1 in state $state\n";
        }
    }
}

# Write out table for each state
$nentries = $hicode - $locode + 1;
$blocks = 1 + ($nentries>>5);
$blocks1 = $blocks - 1;
print "#define CODE_OFFSET $locode\n";
print "#define BLOCKS_PER_STATE $blocks\n";

print "static unsigned long elitab[] = {\n";
$n = 0;
for $s (0 .. $state) {
    @bits = ();
    for $t (@{$toks[$s]}) {
        $tt = $t - $locode;
        $b = $tt >> 5;
        $m = (1 << ($tt & 31));
        if (!defined $bits[$b]) {
            $bits[$b] = $m;
        } else {
            $bits[$b] |= $m;
        }
    }
    for $b (0 .. $blocks1) {
        printf "0x%08lx", (defined $bits[$b]) ? $bits[$b] : 0;
        if ($b < $blocks1) {
            print ", ";
        }
    }
    if ($s < $state) {
        print ", ";
    } else {
        print "  ";
    }
    print "/* state $s */\n";
}
print "};\n\n";
# Write the highest and lowest rules defining subscripts
print "#define LO_SUBSCRIPT $losubscript\n";
print "#define HI_SUBSCRIPT $hisubscript\n";

    



