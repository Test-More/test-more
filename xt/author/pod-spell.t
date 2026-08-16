use strict;
use warnings;

BEGIN {
    eval {
        require Test::Spelling;
    } or do {
        print "1..0 # SKIP Don't have Test::Spelling\n";
        exit 0;
    };
    Test::Spelling->import;
}

my @stopwords;
for (<DATA>) {
    chomp;
    push @stopwords, $_
        unless /\A (?: \# | \s* \z)/msx;    # skip comments, whitespace
}

print "### adding stopwords @stopwords\n";

add_stopwords(@stopwords);
# C.UTF-8 rather than C: POD here is UTF-8, and under a non-UTF-8 locale a
# name like "Böhmer" reaches aspell as two broken fragments no stopword can
# match.
local $ENV{LC_ALL} = 'C.UTF-8';
set_spell_cmd('aspell list -l en --encoding=utf-8');
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
EventFacet
renderers

## computerese
incrementing
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
HASHBASE
renderer

## other jargon, slang
17th
AHHHHHHH
Dummy
globalest
Hmmm
cid
tid
pid
SIGINT
SIGALRM
SIGHUP
SIGTERM
SIGUSR1
SIGUSR2
env
preloading

## Spelled correctly according to google:
recognises

## From Test2-Suite
ithreads
segv
env
17th
AHHHHHHH
Async
AsyncSubtest
AuthorTesting
BUF
BailOnFail
Bowden
Ceccarelli
ClassicCompare
DNE
Daly
Diag
DieOnFail
Dummy
EXODIST
EnvVar
Eryq
EventFacet
ExitSummary
Fennec
Fergal
Getter
Gianni
Glew
Grangaard
Granum
HASHBASE
HashBase
Hmmm
ICal
IPC
NBYTES
Oxley
PARAMS
POS
Pritikin
RSPEC
RealFork
Reinitializes
SCALARREF
SHM
SIGALRM
SIGHUP
SIGINT
SIGTERM
SIGUSR1
SIGUSR2
Schwern
Setter
Skoll
Slaymaker
TIEHANDLE
TODO
TOOLSET
Toolsets
VMS
XNOR
YATH
YESNO
ZeeGee
ansi
async
binkley
blackbox
cid
codeblock
codeblocks
combinatorics
dep
dfs
diag
dir
discoverable
dists
ge
getline
getlines
getpos
getters
globalest
heisenbug
html
isnt
iso
le
masync
miso
num
param
perl-qa
perlish
pid
predeclaring
rebless
recognises
refactoring
refcount
reftype
renderer
renderers
setpos
sref
str
subevent
subevents
subname
subtest
subtests
testability
testsuite
testsuites
tid
tie-ing
todo
todos
toolbuilder
toolset
toolsets
unicode
unoverload
untestable
validators
vmsperl
xUnit
yath
JSONL
shm
instantiable

## contributor names
Böhmer
Rabbitson
TOYAMA
Nao
chocolateboy

## more jargon
diags
deparsing
preload
refcounts
unweakened
DESTROYed
InterceptResult
