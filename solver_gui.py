import pandas as pd
from tkinter import *
import json
import os


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


class SolverWindow(Frame):
    def __init__(self, master=None):
        Frame.__init__(self, master)
        self.master = master
        self.pack()

        self.config = load_config()
        self.word_length = self.config["default_word_length"]
        self.dictionary_file_pattern = self.config["dictionary_file_pattern"]

        self.word_usage_df = self.load_word_list()
        self.all_words = list(self.word_usage_df["word"].values)
        self.possible_words = self.all_words.copy()

        self.guess_history = []

        self.createWidgets()

    def load_word_list(self):
        """Load word list for current word length."""
        filename = self.dictionary_file_pattern.format(length=self.word_length)
        try:
            return pd.read_csv(f"./{filename}")
        except FileNotFoundError:
            print(f"Error: File not found ('./{filename}')")
            return pd.DataFrame()

    def createWidgets(self):
        """Creates the UI widgets."""
        menubar = Menu(self.master)
        self.master.config(menu=menubar)

        settings_menu = Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Settings", menu=settings_menu)

        word_length_menu = Menu(settings_menu, tearoff=0)
        settings_menu.add_cascade(label="Word Length", menu=word_length_menu)
        for length in self.config.get("available_word_lengths", [5]):
            word_length_menu.add_command(
                label=f"{length} letters",
                command=lambda l=length: self.change_word_length(l),
            )

        title = Label(self, text="Lexodle Solver", font=("Roboto", 16, "bold"))
        title.pack(pady=10)

        info_label = Label(
            self,
            text="Enter your guess and feedback:\nG=Green, Y=Yellow, X=Gray",
            font=("Roboto", 10),
        )
        info_label.pack(pady=5)

        input_frame = Frame(self)
        input_frame.pack(pady=10)

        Label(input_frame, text="Guess:").grid(row=0, column=0, padx=5)
        self.guessVar = StringVar()
        guess_entry = Entry(input_frame, textvariable=self.guessVar, width=10)
        guess_entry.grid(row=0, column=1, padx=5)
        guess_entry.bind("<KeyRelease>", self.validate_guess)

        Label(input_frame, text="Feedback:").grid(row=0, column=2, padx=5)
        self.feedbackVar = StringVar()
        feedback_entry = Entry(input_frame, textvariable=self.feedbackVar, width=10)
        feedback_entry.grid(row=0, column=3, padx=5)
        feedback_entry.bind("<KeyRelease>", self.validate_feedback)

        self.add_button = Button(self, text="Add Guess", command=self.add_guess)
        self.add_button.pack(pady=5)

        self.history_label = Label(
            self, text="Guess History:", font=("Roboto", 11, "bold")
        )
        self.history_label.pack(pady=10)

        self.history_frame = Frame(self)
        self.history_frame.pack(pady=5)

        self.result_label = Label(self, text="", font=("Roboto", 12, "bold"), fg="blue")
        self.result_label.pack(pady=10)

        self.possible_label = Label(
            self,
            text=f"Possible words: {len(self.possible_words)}",
            font=("Roboto", 10),
        )
        self.possible_label.pack(pady=5)

        self.clear_button = Button(
            self, text="Clear History", command=self.clear_history
        )
        self.clear_button.pack(pady=10)

    def validate_guess(self, event):
        """Validate guess input - only letters, correct length."""
        current = self.guessVar.get()
        new_value = ""
        for char in current:
            if char.isalpha():
                new_value += char.upper()
        if len(new_value) > self.word_length:
            new_value = new_value[: self.word_length]
        self.guessVar.set(new_value)

    def validate_feedback(self, event):
        """Validate feedback input - only G, Y, X characters."""
        current = self.feedbackVar.get()
        new_value = ""
        for char in current.upper():
            if char in "GXY":
                new_value += char
        if len(new_value) > self.word_length:
            new_value = new_value[: self.word_length]
        self.feedbackVar.set(new_value)

    def add_guess(self):
        """Add a guess and feedback to history, then recalculate."""
        guess = self.guessVar.get().lower()
        feedback = self.feedbackVar.get().upper()

        if len(guess) != self.word_length:
            self.result_label.config(text=f"Guess must be {self.word_length} letters")
            return
        if len(feedback) != self.word_length:
            self.result_label.config(
                text=f"Feedback must be {self.word_length} characters (G/Y/X)"
            )
            return

        self.guess_history.append((guess, feedback))
        self.update_history_display()
        self.solve()

        self.guessVar.set("")
        self.feedbackVar.set("")

    def update_history_display(self):
        """Update the guess history display."""
        for widget in self.history_frame.winfo_children():
            widget.destroy()

        for i, (guess, feedback) in enumerate(self.guess_history):
            Label(
                self.history_frame,
                text=f"{i + 1}. {guess.upper()} -> {feedback}",
                font=("Roboto", 10),
            ).pack()

    def clear_history(self):
        """Clear all guess history and reset."""
        self.guess_history = []
        self.possible_words = self.all_words.copy()
        self.update_history_display()
        self.result_label.config(text="")
        self.possible_label.config(text=f"Possible words: {len(self.possible_words)}")

    def change_word_length(self, length):
        """Change word length and reset."""
        self.word_length = length
        self.word_usage_df = self.load_word_list()
        self.all_words = list(self.word_usage_df["word"].values)
        self.possible_words = self.all_words.copy()
        self.guess_history = []
        self.update_history_display()
        self.result_label.config(text="")
        self.possible_label.config(text=f"Possible words: {len(self.possible_words)}")

    def solve(self):
        """Solve the puzzle based on guess history."""
        self.possible_words = self.all_words.copy()

        for guess, feedback in self.guess_history:
            self.possible_words = self.filter_words(guess, feedback)

        self.possible_label.config(text=f"Possible words: {len(self.possible_words)}")

        if len(self.possible_words) == 0:
            self.result_label.config(text="No matching words found!", fg="red")
            return
        elif len(self.possible_words) == 1:
            self.result_label.config(
                text=f"Answer: {self.possible_words[0].upper()}", fg="green"
            )
            return

        best_guess = self.find_best_guess()
        self.result_label.config(text=f"Recommended: {best_guess.upper()}", fg="blue")

    def filter_words(self, guess, feedback):
        """Filter words based on guess and feedback."""
        filtered = []

        for word in self.possible_words:
            if self.matches_feedback(word, guess, feedback):
                filtered.append(word)

        return filtered

    def matches_feedback(self, word, guess, feedback):
        """Check if word matches the feedback for the given guess."""
        word = word.lower()
        guess = guess.lower()

        target_counts = {}
        for char in word:
            target_counts[char] = target_counts.get(char, 0) + 1

        guess_used = [False] * len(guess)

        for i, char in enumerate(feedback):
            if char == "G":
                if guess[i] != word[i]:
                    return False
                guess_used[i] = True
                target_counts[guess[i]] -= 1

        for i, char in enumerate(feedback):
            if char == "Y" and not guess_used[i]:
                if guess[i] not in word or word[i] == guess[i]:
                    return False
                if target_counts.get(guess[i], 0) <= 0:
                    return False
                target_counts[guess[i]] -= 1
                guess_used[i] = True

        for i, char in enumerate(feedback):
            if char == "X" and not guess_used[i]:
                if guess[i] in word:
                    if target_counts.get(guess[i], 0) > 0:
                        return False

        return True

    def find_best_guess(self):
        """Find the best next guess using entropy-based scoring."""
        if len(self.possible_words) <= 2:
            return self.possible_words[0]

        best_score = -1
        best_word = self.possible_words[0]

        candidates = (
            self.all_words if len(self.possible_words) > 20 else self.possible_words
        )

        for word in candidates[:100]:
            score = self.calculate_score(word)
            if score > best_score:
                best_score = score
                best_word = word

        return best_word

    def calculate_score(self, guess):
        """Calculate entropy score for a guess."""
        groups = {}

        for word in self.possible_words:
            feedback = self.get_feedback(guess, word)
            groups[feedback] = groups.get(feedback, 0) + 1

        total = len(self.possible_words)
        entropy = 0

        for count in groups.values():
            p = count / total
            if p > 0:
                entropy -= p * (p**0.5)

        return entropy

    def get_feedback(self, guess, word):
        """Get feedback pattern for guess against word."""
        guess = guess.lower()
        word = word.lower()

        feedback = ["X"] * len(guess)
        target_counts = {}

        for char in word:
            target_counts[char] = target_counts.get(char, 0) + 1

        for i, char in enumerate(guess):
            if char == word[i]:
                feedback[i] = "G"
                target_counts[char] -= 1

        for i, char in enumerate(guess):
            if feedback[i] == "G":
                continue
            if char in target_counts and target_counts[char] > 0:
                feedback[i] = "Y"
                target_counts[char] -= 1

        return "".join(feedback)


if __name__ == "__main__":
    root = Tk()
    root.option_add("*Font", "Roboto 13")
    root.title("Lexodle Solver")
    root.geometry("450x500")
    app = SolverWindow(root)
    root.mainloop()
