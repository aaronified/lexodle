import pandas as pd
import time
import sys
import json
from collections import defaultdict
import itertools


def load_config():
    """Load configuration from config.json."""
    try:
        with open("./config.json", "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return {
            "default_word_length": 5,
            "dictionary_file_pattern": "lexodle_list_{length}.csv",
        }


class BranchAndBoundSolver:
    def __init__(self, word_list, all_chars):
        self.word_list = word_list
        self.all_chars = all_chars
        self.word_char_sets = {word: set(word) for word in word_list}
        self.best_solution = None
        self.min_solution_length = float("inf")
        self.total_combinations_checked = 0

    def is_promising(self, current_set, covered_chars, n):
        """Checks if the current partial solution is promising."""
        if len(current_set) >= self.min_solution_length:
            return False  # Already longer than the best solution found

        if len(covered_chars) >= n:
            return True

        # Heuristic: Estimate if we can reach n with remaining words
        remaining_chars = self.all_chars - covered_chars
        remaining_words = [word for word in self.word_list if word not in current_set]

        if not remaining_words:
            return False

        max_chars_per_word = max(
            len(self.word_char_sets[word] & remaining_chars) for word in remaining_words
        )

        if len(covered_chars) + max_chars_per_word * len(remaining_words) < n:
            return False

        return True

    def branch_and_bound(self, current_set, covered_chars, n, index):
        """Recursive branch and bound algorithm."""
        self.total_combinations_checked += 1

        if len(covered_chars) >= n:
            if len(current_set) < self.min_solution_length:
                self.min_solution_length = len(current_set)
                self.best_solution = current_set[:]
            return

        if index >= len(self.word_list):
            return

        if not self.is_promising(current_set, covered_chars, n):
            return

        # Explore including the current word
        word = self.word_list[index]
        new_covered_chars = covered_chars | self.word_char_sets[word]
        self.branch_and_bound(current_set + [word], new_covered_chars, n, index + 1)

        # Explore excluding the current word
        self.branch_and_bound(current_set, covered_chars, n, index + 1)

    def solve(self, n):
        """Starts the branch and bound algorithm."""
        self.branch_and_bound([], set(), n, 0)
        return self.best_solution, self.total_combinations_checked


def get_min_word_set_branch_and_bound(n):
    """
    Finds the minimum set of words that cover at least n unique characters using branch and bound.

    Args:
        n (int): The minimum number of unique characters to cover.

    Returns:
        tuple: A tuple containing:
            - list: The minimum set of words.
            - list: The characters not covered by the minimum set.
            - int: The number of combinations checked (for comparison).
            - float: The time taken.
    """
    start_time = time.time()
    config = load_config()
    word_length = config.get("default_word_length", 5)
    filename = config["dictionary_file_pattern"].format(length=word_length)

    word_df = pd.read_csv(f"./{filename}")
    word_list = word_df["word"].tolist()
    all_chars = set("abcdefghijklmnopqrstuvwxyz")

    solver = BranchAndBoundSolver(word_list, all_chars)
    min_word_set, total_combinations_checked = solver.solve(n)

    covered_chars = set("".join(min_word_set)) if min_word_set else set()
    missed_chars = all_chars - covered_chars
    end_time = time.time()
    time_taken = end_time - start_time

    print(f"\nTotal combinations checked: {total_combinations_checked}")
    return min_word_set, list(missed_chars), total_combinations_checked, time_taken


if __name__ == "__main__":
    n = int(input("Enter the number of characters to cover: "))
    min_word_set, missed_chars, total_combinations_checked, time_taken = (
        get_min_word_set_branch_and_bound(n)
    )
    print(f"Min word set to cover {n} characters: {min_word_set}")
    print(f"Missed characters: {missed_chars}")
    print(f"Total time taken: {time_taken:.4f} seconds")
