# The word lists of the themed wordle

`living.tsv`, `food.tsv`, `minerals.tsv`, `anatomy.tsv` and `math.tsv` are made by
`tools/build_themes.py` from three sources, and then reviewed by hand (the words in
`tools/themes/deny.txt` are left out). A line is a word, the subthemes it belongs to, and how
often the word is used in English (the count of `assets/words/en.txt`).

## WordNet

The groups of words (which are animals, which are bones, which are metals) come in part from
WordNet 3.0, whose licence requires this notice to appear on all copies and modifications:

> WordNet 3.0 Copyright 2006 by Princeton University. All rights reserved.
>
> THIS SOFTWARE AND DATABASE IS PROVIDED "AS IS" AND PRINCETON UNIVERSITY MAKES NO
> REPRESENTATIONS OR WARRANTIES, EXPRESS OR IMPLIED. BY WAY OF EXAMPLE, BUT NOT LIMITATION,
> PRINCETON UNIVERSITY MAKES NO REPRESENTATIONS OR WARRANTIES OF MERCHANTABILITY OR FITNESS FOR
> ANY PARTICULAR PURPOSE OR THAT THE USE OF THE LICENSED SOFTWARE, DATABASE OR DOCUMENTATION WILL
> NOT INFRINGE ANY THIRD PARTY PATENTS, COPYRIGHTS, TRADEMARKS OR OTHER RIGHTS.
>
> The name of Princeton University or Princeton may not be used in advertising or publicity
> pertaining to distribution of the software and/or database. Title to copyright in this
> software, database and any associated documentation shall at all times remain with Princeton
> University and LICENSEE agrees to preserve same.

(https://wordnet.princeton.edu/license-and-commercial-use)

## Wiktionary

Which words belong to a topic also comes from the topic categories of the English Wiktionary
(en.wiktionary.org), licensed under
[Creative Commons Attribution-ShareAlike 4.0](https://creativecommons.org/licenses/by-sa/4.0/),
read from its public database dumps by `tools/wiktionary_topics.py`. Only the fact that a word is
in a category is used; no text of an entry is.
