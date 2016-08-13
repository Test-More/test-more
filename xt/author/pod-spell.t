use strict;
use warnings;

use Test::Spelling;

my @stopwords;
for (<DATA>) {
    chomp;
    push @stopwords, $_
        unless /\A (?: \# | \s* \z)/msx;    # skip comments, whitespace
}

print "### adding stopwords @stopwords\n";

add_stopwords(@stopwords);
local $ENV{LC_ALL} = 'C';
set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok;

__DATA__
## personal names
binkley
Bowden
Daly
dfs
Eryq
EXODIST
Fergal
Glew
Granum
Oxley
Pritikin
Schwern
Skoll
Slaymaker
ZeeGee

## proper names
Fennec
ICal
xUnit

## test jargon
Diag
diag
isnt
subtest
subtests
testsuite
testsuites
TODO
todo
todos
untestable

## computerese
blackbox
BUF
codeblock
combinatorics
dir
getline
getlines
getpos
Getter
getters
HashBase
heisenbug
IPC
NBYTES
param
perlish
perl-qa
POS
predeclaring
rebless
refactoring
refcount
Reinitializes
SCALARREF
setpos
Setter
SHM
sref
subevent
subevents
testability
TIEHANDLE
tie-ing
unoverload
VMS
vmsperl
YESNO
ansi
html

## other jargon, slang
17th
AHHHHHHH
Dummy
globalest
Hmmm
