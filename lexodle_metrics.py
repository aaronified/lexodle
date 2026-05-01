import pickle
import os
import pandas as pd
import numpy as np
from typing import Dict, List, Tuple, Optional


class MetricsEngine:
    """Handles precomputation and caching of partition data for skill/luck metrics."""

    def __init__(self, word_length: int, dictionary_file: str = "lexodle_list.csv", progress_callback=None):
        self.word_length = word_length
        self.dictionary_file = dictionary_file
        self.words: List[str] = []
        self.guess_partitions: Dict[str, Dict[Tuple[int, ...], int]] = {}
        self.word_to_index: Dict[str, int] = {}
        self.cache_dir = "cache"
        self.progress_callback = progress_callback
        self._ensure_cache_dir()
        self.load_or_compute_partitions()

    def _ensure_cache_dir(self) -> None:
        """Ensure the cache directory exists."""
        if not os.path.exists(self.cache_dir):
            os.makedirs(self.cache_dir)

    @property
    def cache_path(self) -> str:
        """Return the cache file path for the current word length."""
        return os.path.join(self.cache_dir, f"partitions_{self.word_length}.pkl")

    def _get_word_list_hash(self, df: pd.DataFrame) -> int:
        """Get a simple hash of the word list for cache invalidation."""
        return len(self.words)

    def load_or_compute_partitions(self) -> None:
        """Load cached partitions or compute them if cache is invalid."""
        cache_path = self.cache_path

        # Try to load from cache
        if os.path.exists(cache_path):
            try:
                with open(cache_path, "rb") as f:
                    data = pickle.load(f)
                self.words = data["words"]
                self.guess_partitions = data["guess_partitions"]
                self.word_to_index = data.get("word_to_index", {w: i for i, w in enumerate(self.words)})
                print(f"Loaded cached partitions for {self.word_length}-letter words ({len(self.words)} words)")
                return
            except Exception as e:
                print(f"Cache load failed: {e}, recomputing...")

        # Compute partitions
        print(f"Computing partitions for {self.word_length}-letter words...")
        self._compute_partitions()

        # Save to cache
        try:
            with open(cache_path, "wb") as f:
                pickle.dump({
                    "words": self.words,
                    "guess_partitions": self.guess_partitions,
                    "word_to_index": self.word_to_index,
                }, f)
            print(f"Saved cached partitions to {cache_path}")
        except Exception as e:
            print(f"Cache save failed: {e}")

    def _compute_partitions(self) -> None:
        """Compute the partition bitmasks for all valid words."""
        # Load the dictionary
        try:
            df = pd.read_csv(self.dictionary_file)
        except FileNotFoundError:
            # Fallback to the old pattern
            legacy_file = f"lexodle_list_{self.word_length}.csv"
            try:
                df = pd.read_csv(legacy_file)
            except FileNotFoundError:
                print(f"Error: Could not find {self.dictionary_file} or {legacy_file}")
                self.words = []
                return

        # Filter by letter count
        if "lettercount" in df.columns:
            df = df[df["lettercount"] == self.word_length]
        else:
            df = df[df["word"].str.len() == self.word_length]

        # Reset index and get words
        df = df.reset_index(drop=True)
        self.words = [w.lower() for w in df["word"].values]
        self.word_to_index = {w: i for i, w in enumerate(self.words)}

        if not self.words:
            print(f"No {self.word_length}-letter words found!")
            return

        print(f"Computing partitions for {len(self.words)} words...")

        # Build the evaluation function mapping
        # Pattern encoding: 0=green, 1=yellow, 2=red
        for guess_idx, guess in enumerate(self.words):
            partitions: Dict[Tuple[int, ...], int] = {}

            for answer_idx, answer in enumerate(self.words):
                pattern = self._evaluate_pattern(guess, answer)
                bit = 1 << answer_idx
                if pattern in partitions:
                    partitions[pattern] |= bit
                else:
                    partitions[pattern] = bit

            self.guess_partitions[guess] = partitions

            if (guess_idx + 1) % 500 == 0:
                pct = int((guess_idx + 1) / len(self.words) * 100)
                print(f"  Processed {guess_idx + 1}/{len(self.words)} guesses...")
                if self.progress_callback:
                    self.progress_callback(pct, f"Processing: {guess_idx + 1}/{len(self.words)} words...")

        print(f"Partition computation complete!")
        if self.progress_callback:
            self.progress_callback(100, "Complete!")

    def _evaluate_pattern(self, guess: str, answer: str) -> Tuple[int, ...]:
        """Evaluate the pattern of a guess against an answer.
        
        Returns a tuple of color codes: 0=green, 1=yellow, 2=red.
        Matches the evaluate_guess color hex codes:
        - Green (#C6F4D6): correct letter, correct position
        - Yellow (#F7DC6F): correct letter, wrong position  
        - Red (#FFC5C5): letter not in answer
        """
        pattern = [2] * len(guess)  # Default to red
        target_counts = {}
        guess_counts = {}

        # Count letters
        for char in answer:
            target_counts[char] = target_counts.get(char, 0) + 1
        for char in guess:
            guess_counts[char] = guess_counts.get(char, 0) + 1

        # First pass: mark greens
        for i, char in enumerate(guess):
            if char == answer[i]:
                pattern[i] = 0  # Green
                target_counts[char] -= 1
                guess_counts[char] -= 1

        # Second pass: mark yellows
        for i, char in enumerate(guess):
            if pattern[i] != 0:  # Not already green
                if char in target_counts and target_counts[char] > 0 and guess_counts[char] > 0:
                    pattern[i] = 1  # Yellow
                    target_counts[char] -= 1
                    guess_counts[char] -= 1

        return tuple(pattern)

    def compute_skill(self, eligible_mask: int) -> float:
        """Compute the skill metric for the current eligible word set.
        
        For each possible guess, compute the expected partition size.
        Skill = (N - E) / (N - 1) * 100, where E is the expected partition size.
        
        Args:
            eligible_mask: Bitmask of currently eligible words (answers)
            
        Returns:
            Skill score (0-100)
        """
        N = bin(eligible_mask).count("1")
        
        if N <= 1:
            return 100.0
        
        # Get the list of eligible word indices
        eligible_indices = [i for i in range(len(self.words)) if eligible_mask & (1 << i)]
        
        # Build eligible word mask for quick lookup
        eligible_set = set(eligible_indices)
        
        best_skill = 0.0
        
        # For each possible guess, compute expected partition size
        for guess_word, partitions in self.guess_partitions.items():
            # Skip if guess is not in eligible set (optional optimization)
            # We consider all possible guesses from the full word list
            
            total_size_sq = 0
            total_count = 0
            
            for pattern, partition_mask in partitions.items():
                # Intersect with eligible answers
                eligible_partition = partition_mask & eligible_mask
                size = bin(eligible_partition).count("1")
                if size > 0:
                    total_size_sq += size * size
                    total_count += size
            
            if total_count == 0:
                continue
            
            # Expected partition size (uniform over answers)
            expected_size = total_size_sq / N
            
            # Skill = (N - E) / (N - 1) * 100
            skill = (N - expected_size) / (N - 1) * 100.0
            
            if skill > best_skill:
                best_skill = skill
        
        return best_skill

    def compute_luck(self, guess_word: str, eligible_before: int, eligible_after: int) -> float:
        """Compute the luck metric for a guess.
        
        Luck = (N_before - N_after) / (N_before - expected_n) * 100
        
        Args:
            guess_word: The guessed word
            eligible_before: Bitmask of eligible words before the guess
            eligible_after: Bitmask of eligible words after the guess
            
        Returns:
            Luck score (can be >100 or negative)
        """
        N_before = bin(eligible_before).count("1")
        N_after = bin(eligible_after).count("1")
        
        if N_before <= 1:
            return 0.0
        
        # Compute expected partition size for this guess
        partitions = self.guess_partitions.get(guess_word)
        if not partitions:
            return 0.0
        
        total_size_sq = 0
        total_count = 0
        
        for pattern, partition_mask in partitions.items():
            eligible_partition = partition_mask & eligible_before
            size = bin(eligible_partition).count("1")
            if size > 0:
                total_size_sq += size * size
                total_count += size
        
        if total_count == 0:
            return 0.0
        
        expected_n = total_size_sq / N_before
        
        # Avoid division by zero
        if N_before - expected_n == 0:
            return 0.0
        
        luck = (N_before - N_after) / (N_before - expected_n) * 100.0
        return luck

    def get_eligible_mask(self, eligible_words: List[str]) -> int:
        """Convert a list of eligible words to a bitmask."""
        mask = 0
        for word in eligible_words:
            word_lower = word.lower()
            if word_lower in self.word_to_index:
                mask |= 1 << self.word_to_index[word_lower]
        return mask

    def get_word_from_mask(self, mask: int) -> Optional[str]:
        """Get a single word from a bitmask (if only one bit is set)."""
        if mask == 0:
            return None
        # Check if it's a single bit
        if mask & (mask - 1) == 0:
            idx = mask.bit_length() - 1
            if idx < len(self.words):
                return self.words[idx]
        return None