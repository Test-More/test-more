use strict;
use warnings;

use Test::Spelling;

my @stopwords;
for (<DATA>) {
    chomp;
    push @stopwords, $_
        unless /\A (?: \# | \s* \z)/msx;    # skip comments, whitespace
}

add_stopwords(@stopwords);
local $ENV{LC_ALL} = 'C';
set_spell_cmd('aspell list -l en');
all_pod_files_spelling_ok;

__DATA__
## personal names
Ceccarelli
Gianni
Granum

## proper names

## test jargon
diag
subtest
subtests
TODO
todo

## computerese
AuthorTesting
BailOnFail
ClassicCompare
codeblock
dep
DieOnFail
DNE
EnvVar
ExitSummary
ge
le
num
RealFork
reftype
str
subname
tid
unicode
validators

## other jargon, slang
