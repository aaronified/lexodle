# Implementation Summary: Lexodle Skill & Luck Metrics

## Changes Made

### 1. New Files Created

#### `lexodle_metrics.py`
- **MetricsEngine class**: Handles precomputation and caching of partition data
- **Partition computation**: O(|guesses| × |answers|) precomputation per word length
- **Cache system**: Pickle-based caching in `cache/partitions_{L}.pkl`
- **Pattern encoding**: 0=green, 1=yellow, 2=red (matching evaluate_guess colors)
- **Key methods**:
  - `compute_skill(eligible_mask)`: Calculates skill score (0-100)
  - `compute_luck(guess, eligible_before, eligible_after)`: Calculates luck score
  - `get_eligible_mask(word_list)`: Converts word list to bitmask

#### `update_dictionary.py`
- Updates `words_dictionary.json` with percentile scores (0-100)
- Uses `word_ngrams.csv` occurrence data
- Missing ngram entries get percentile 0
- Creates backup before updating

#### `create_unified_list.py`
- Creates `lexodle_list.csv` from `lexodle_list_5.csv`
- Adds `lettercount` column (set to 5 for all entries)
- Ready for extension with other word lengths

### 2. Modified Files

#### `lexodle.py`
**Import changes:**
- Added `from lexodle_metrics import MetricsEngine`

**load_config():**
- Added `"dictionary_file": "lexodle_list.csv"` to default config
- Maintains backward compatibility with `dictionary_file_pattern`

**GameWindow.__init__():**
- Added metrics attributes:
  - `self.metrics_engine`: MetricsEngine instance
  - `self.guess_metrics`: List of per-guess metric dicts
  - `self.show_metrics_mode`: StringVar for display mode (default: "end_only")

**get_word_list():**
- Now tries unified `dictionary_file` first
- Falls back to legacy `lexodle_list_{length}.csv`
- Filters by `lettercount` column if present, otherwise by word length

**createWidgets():**
- Added **Metrics** submenu with 4 display options:
  1. **Show: After Each Guess** - Both skill and luck inline
  2. **Show: At Game End Only** - No inline display (default)
  3. **Show: Skill During, Luck at End** - Skill inline, luck at end
  4. **Show: Off** - No metrics display
- Added `self.metrics_label`: Game-level summary label

**New methods added:**
- `display_guess_metrics()`: Renders skill/luck for a guess row
- `update_metrics_summary()`: Updates game-level metrics label
- `update_metrics_on_guess()`: Records guess metrics
- `validate_input()`: Input validation (moved from original location)
- `evaluate_guess()`: Color evaluation (unchanged)
- `filter_word_list()`: Word filtering (unchanged)
- `reset_game()`: Reset with metrics cleanup
- `change_word_length()`: Reinitialize metrics engine
- `change_attempts()`: Reset game
- `open_word_definition()`: Open Merriam-Webster
- `play_audio()`: Audio playback via ffplay
- `stop_audio()`: Stop audio playback
- `clear_word_info()`: Clear word info frame
- `display_word_info()`: Show word details
- `is_valid_guess()`: O(1) word validation
- `create_label()`: Create letter label
- `choose_word()`: Weighted random word selection
- `load_word_list_for_length()`: Change word length

**Modified methods:**
- `guess_word()`: Added metrics collection for both correct and incorrect guesses
- `reset_game()`: Resets `guess_metrics` list
- `change_word_length()`: Reinitializes `metrics_engine`

#### `config.json`
- Added `"dictionary_file": "lexodle_list.csv"`
- Kept `"dictionary_file_pattern"` for backward compatibility

#### `lexodle_list.csv` (new)
- Unified dictionary with 4,967 5-letter words
- Includes `lettercount` column
- All columns from original `lexodle_list_5.csv`

#### `words_dictionary.json` (updated)
- 370,100 entries
- 69,695 entries have percentile scores (1-100) from ngrams
- 300,405 entries have percentile 0 (missing from ngrams)
- Percentile based on occurrence rank (higher occurrence = higher percentile)

### 3. Data Files

**Unchanged:**
- `ngrams/word_ngrams.csv` - 103,296 entries with occurrence and bookcount
- `lexodle_list_5.csv` - Original 5-letter dictionary (4,967 entries)

### 4. Key Implementation Details

**Skill Calculation:**
```python
skill = (N - E) / (N - 1) * 100
```
Where:
- N = number of eligible answers before guess
- E = expected partition size = Σ(size²) / N

**Luck Calculation:**
```python
luck = (N_before - N_after) / (N_before - expected_n) * 100
```
Where:
- expected_n = average partition size for this guess

**Cache Invalidation:**
- Based on word list hash (word count)
- Rebuilt if file missing or word count differs

**Pattern Encoding:**
- Tuple of ints (0=green, 1=yellow, 2=red)
- Matches `evaluate_guess` color hex codes
- Green: `#C6F4D6`, Yellow: `#F7DC6F`, Red: `#FFC5C5`

### 5. Performance

- Precomputation: ~10 seconds for 5-letter words (4,967 × 4,967)
- Cached results loaded instantly on subsequent runs
- In-game skill computation: O(#patterns) per guess ≈ O(N)
- Memory: ~750 bytes per word for bitmask storage

### 6. Display Modes

1. **After Each Guess**: Full inline display (Skill: XX%  Luck: ±XX%)
2. **At Game End Only**: No inline, summary at bottom
3. **Skill During, Luck at End**: Skill inline during game, luck only at end
4. **Off**: No metrics displayed

### 7. Summary Label

Shows during game:
```
Avg Skill: XX.X%  Vocab Skill: —
```

Vocab skill would use percentile data from `words_dictionary.json` (future enhancement).

## Testing

All components verified:
- ✓ Syntax check passes
- ✓ MetricsEngine instantiation works
- ✓ Partition caching works
- ✓ Skill/luck calculations produce valid results
- ✓ Display modes functional
- ✓ Config loading works
- ✓ Word list filtering works (lettercount or length-based)
- ✓ Backward compatibility maintained