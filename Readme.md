# Lexodle

A Wordle-inspired word game with dictionary enrichment, solver tools, and optimization utilities.

## License

See [LICENSE](LICENSE) file for details.

## Acknowledgments

This project was developed with assistance from [KiloCode](https://kilo.ai), an AI coding assistant.

## Data Sources

- Google Ngrams (2020 English 1-grams)  
  https://storage.googleapis.com/books/ngrams/books/20200217/eng/eng-1-ngrams_exports.html

- English word list (MIT License)  
  https://github.com/dwyl/english-words

- Dictionary API (used via public endpoint; subject to its terms)  
  https://api.dictionaryapi.dev/api/v2/entries/en/

>- Large datasets are not included in this repository.
>- External data is subject to respective licenses and terms of use.

## Project Structure

```
lexodle/
├── ngrams/                      # Google Ngram data
├── dictionary_audio/            # Downloaded pronunciation audio files
├── dictionary_files/            # Additional dictionary data
├── lexodle_list_5.csv           # 5-letter game word list
├── config.json                  # Game configuration
├── lexodle_details.csv          # Enriched word data (created by dictionary_builder.py)
├── ngram_reader.py              # Process Google Ngram data
├── dictionary_builder.py        # Enrich words with dictionary API
├── lexodle.py                   # Full-featured game
├── lexodle_simulator.py         # Simplified game
├── lexodle_solver.py            # CLI puzzle solver
├── solver_gui.py                # GUI puzzle solver
├── top_guesser.py               # Letter coverage optimizer
└── Readme.md
```

## Data Pipeline

```
ngram_reader.py 
    ↓
./ngrams/word_ngrams.csv (word frequencies)
    ↓
dictionary_builder.py 
    ↓
./lexodle_details.csv + audio files
    ↓
./lexodle_list_5.csv (final game word list)
    ↓
lexodle.py (game)
```

## Scripts

### ngram_reader.py

Processes Google Ngram data to extract word frequency statistics.

**Inputs:** Gzip files from `./ngrams/` (downloaded from Google Ngrams)

**Outputs:** `./ngrams/word_ngrams.csv`
- `word`: lowercase word
- `occurrence`: total count across books
- `bookcount`: number of books containing the word

Filters to words with count >100,000 and appearing in >1,000 books.

---

### dictionary_builder.py

Enriches word list with dictionary data from the Free Dictionary API.

**Inputs:**
- `./ngrams/word_ngrams.csv`
- https://api.dictionaryapi.dev/api/v2/entries/en/{word}

**Outputs:**
- `./lexodle_details.csv` - `word`, `phonetics`, `meanings`, `sourceUrls`, `audio`
- `./dictionary_audio/{word}.mp3` - pronunciation audio

Filters to 5-letter words only. Saves intermediate results every 1000 words.

---

### lexodle.py

Full-featured GUI Lexodle game with word definitions and audio.

**Inputs:**
- `./lexodle_list_5.csv` - word list with metadata
- `./dictionary_audio/` - audio files
- Merriam-Webster (online)

**Features:**
- Customizable word length and attempts via Settings menu
- Weighted random word selection (based on word frequency)
- Standard Lexodle coloring: green (correct position), yellow (wrong position), red (not in word)
- Displays word info: phonetics, definitions, synonyms, antonyms
- Plays pronunciation audio
- Links to Merriam-Webster dictionary
- Shows eligible word count after each guess

---

### lexodle_simulator.py

Simplified Lexodle game (no dictionary metadata).

**Inputs:** `./lexodle_list_5.csv`

**Features:**
- Basic Tkinter GUI
- Uniform random word selection
- Standard Lexodle coloring

---

### lexodle_solver.py

CLI tool to help solve Lexodle puzzles.

**Inputs:** `./lexodle_list_5.csv`

**Functions:**
- `filter_words_by_absent_letters()` - exclude words with certain letters
- `filter_words_by_present_letters_and_positions()` - filter by required letters and position patterns

---

### solver_gui.py

GUI puzzle solver with entropy-based recommendation.

**Inputs:** `./lexodle_list_5.csv`

**Features:**
- Enter guess + feedback (G=Green, Y=Yellow, X=Gray)
- Recommends best next guess using entropy scoring
- Shows possible words remaining
- Settings menu for word length

---

### top_guesser.py

Finds minimum set of words covering all 26 letters.

**Inputs:** `./lexodle_list_5.csv`

**Output:** Minimum word set that covers n unique characters

Uses branch and bound algorithm with heuristic pruning.

---

## Setup

1. Download Google Ngram gz files to `./ngrams/`
2. Run `python ngram_reader.py` to create `word_ngrams.csv`
3. Run `python dictionary_builder.py` to enrich with dictionary data
4. Combine data into `lexodle_list_5.csv`
5. Run `python lexodle.py` to play
6. Run `python solver_gui.py` to use the solver

## Notes

- Large `.gz` files are not included in this repo. Download and place them in `ngrams/` before running scripts.
- Audio files are downloaded on-demand by `dictionary_builder.py`.
- The game requires ffmpeg for audio playback (configured in `lexodle.py`).
- Configuration is stored in `config.json` - controls default word length, attempts, and dictionary file pattern.
- Currently supports 5-letter words. Extend to 4/6 letters by building new dictionary files.
