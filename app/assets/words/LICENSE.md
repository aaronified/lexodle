# Licence of the word lists

The word lists in this folder (`*.txt` and `languages.json`) are adapted from
[wordfreq](https://github.com/rspeer/wordfreq) by Robyn Speer, whose data files may be
redistributed under the **Creative Commons Attribution-ShareAlike 4.0 International** licence
(<https://creativecommons.org/licenses/by-sa/4.0/>). The lists here are offered under the same
licence, CC BY-SA 4.0. The licence covers these files, not the rest of the app.

## Changes made

Each list is a subset of one language's wordfreq vocabulary: Latin letters only, 4 to 8 letters,
filtered to the words a spelling dictionary accepts, at most 6,000 per length, in order of frequency, with each word's
frequency kept as its weight. See `SOURCES.md` and `tools/build_words.py`.

## Credit

wordfreq contains data from the following, to whom credit is due:

- Google Books Ngrams and Syntactic Ngrams (<http://books.google.com/ngrams>)
- The Leeds Internet Corpus, University of Leeds Centre for Translation Studies
- Wikipedia (CC BY-SA)
- ParaCrawl (<https://paracrawl.eu>)
- OPUS OpenSubtitles 2018, from the OpenSubtitles project (<http://www.opensubtitles.org/>)
- the SUBTLEX word lists (SUBTLEX-US, -UK, -CH, -DE, -NL) by Marc Brysbaert et al., freely
  available data (<http://crr.ugent.be/programs-data/subtitle-frequencies>)
- word counts from the Twitter streaming API (statistics only; no content is republished)

Cite: Robyn Speer (2022). *rspeer/wordfreq: v3.0*. Zenodo. <https://doi.org/10.5281/zenodo.7199437>

## Dictionaries

The spelling dictionaries used to filter the lists are not included here. They are listed, with the
licence each states, in `SOURCES.md`.
