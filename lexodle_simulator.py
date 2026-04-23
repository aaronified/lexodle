import random
import pandas as pd
import json
from tkinter import *
import webbrowser
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


class GameWindow(Frame):
    def __init__(self, master=None):
        """Initializes a new GameWindow object."""
        Frame.__init__(self, master)
        self.master = master
        self.pack()

        self.config = load_config()
        self.word_length = self.config["default_word_length"]
        self.attempts_init = self.config["default_attempts"]
        self.dictionary_file_pattern = self.config["dictionary_file_pattern"]

        self.attempts = self.attempts_init
        self.word_list = self.get_word_list()
        self.valid_words = set(w.lower() for w in self.word_list)
        self.target_word = self.choose_word()
        self.eligible_word_list = list(self.word_list)
        self.guess_rows = []
        self.previous_guesses = []
        self.block_old_guesses = self.config.get("block_old_guesses", True)
        self.createWidgets()

    def get_word_list(self):
        """Returns a list of words for the configured word length."""
        filename = self.dictionary_file_pattern.format(length=self.word_length)
        try:
            word_usage_df = pd.read_csv(f"./{filename}")
            word_set = set(word_usage_df["word"].values)
            return list(word_set)
        except FileNotFoundError:
            print(f"Error: Required file not found. Check path ('./{filename}').")
            return []
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
            return []

    def is_valid_guess(self, guess):
        """Checks if the guess is a valid word using O(1) set lookup."""
        return guess.lower() in self.valid_words

    def create_label(self, text, color):
        """Creates a styled Label."""
        return Label(
            self.master,
            text=text.upper(),
            bg=color,
            width=3,
            borderwidth=0.1,
            relief="solid",
        )

    def choose_word(self):
        """Chooses a random word."""
        if not self.word_list:
            return ""
        return random.choice(self.word_list)

    def createWidgets(self):
        """Creates the UI widgets."""
        self.guessVar = StringVar()
        self.resetButton = Button(self, text="Reset Game", command=self.reset_game)
        self.resetButton.pack()
        self.label = Label(
            self, text=f"Guess the word, you have {self.attempts} attempts left:"
        )
        self.label.pack()

        self.entry = Entry(self, textvariable=self.guessVar)
        self.entry.pack()
        self.entry.bind("<KeyRelease>", self.validate_input)

        self.button = Button(self, text="Submit guess", command=self.guess_word)
        self.button.pack()

        # Use a Text widget instead of a Label for the result
        self.resultText = Text(
            self,
            height=1,
            wrap="word",
            borderwidth=0,
            highlightthickness=0,
            bg=self.master["bg"],  # Set the background to match the master
        )
        self.resultText.pack()
        self.resultText.tag_configure(
            "center", justify="center"
        )  # Create a tag for centering
        self.resultText.config(state="disabled")  # Make it read-only

        self.guesses_frame = Frame(self)
        self.guesses_frame.pack()
        self.eligible_label = Label(
            self, text=f"Eligible words left: {len(self.eligible_word_list)}"
        )
        self.eligible_label.pack()

    def validate_input(self, event):
        """Validates and modifies the input in the Entry widget."""
        current_value = self.guessVar.get()
        new_value = ""

        # Restrict to alphabet characters and make uppercase
        for char in current_value:
            if char.isalpha():
                new_value += char.upper()

        # Restrict the input to a maximum length of 5
        if len(new_value) > self.word_length:
            new_value = new_value[: self.word_length]

        # Update the entry with the validated value
        self.guessVar.set(new_value)

    def evaluate_guess(self, word, guess):
        """Evaluates the guess and creates feedback labels."""
        evaluation_labels = Frame(self.guesses_frame)
        evaluation_labels.pack()
        self.guess_rows.append(evaluation_labels)

        result = []
        evaluation_colors = []
        target_dict = {char: word.count(char) for char in set(word)}

        for i, char in enumerate(guess):
            if char == word[i]:
                label = self.create_label(
                    char, "#C6F4D6"
                )  # Light green: Correct letter and position
                evaluation_colors.append("#C6F4D6")
            elif char != word[i] and target_dict.get(char, 0) > 0:
                label = self.create_label(
                    char, "#F7DC6F"
                )  # Light yellow: Correct letter but wrong position
                evaluation_colors.append("#F7DC6F")
                target_dict[char] -= 1
            else:
                label = self.create_label(
                    char, "#FFC5C5"
                )  # Light red: Incorrect letter
                evaluation_colors.append("#FFC5C5")
            result.append(label)

        for label in result:
            label.pack(side=LEFT, in_=evaluation_labels)

        return evaluation_colors

    def filter_word_list(self, guess, evaluation):
        """Filters the word list based on the guess and evaluation."""
        new_word_list = []
        for word in self.eligible_word_list:
            valid = True
            for i, char in enumerate(guess):
                if evaluation[i] == "#C6F4D6":
                    if word[i] != char:
                        valid = False
                        break
                elif evaluation[i] == "#F7DC6F":
                    if char not in word or word[i] == char:
                        valid = False
                        break
                elif evaluation[i] == "#FFC5C5":
                    if char in word:
                        valid = False
                        break
            if valid:
                new_word_list.append(word)
        return new_word_list

    def reset_game(self):
        """Resets the game state."""
        self.attempts = self.attempts_init
        self.resultText.config(state="normal")  # Enable the text widget
        self.resultText.delete("1.0", "end")
        self.resultText.config(state="disabled")  # Make it read-only
        for row in self.guess_rows:
            row.destroy()
        self.guess_rows = []
        self.previous_guesses = []  # clear previous guesses as well
        self.label.config(
            text=f"Guess the word, you have {self.attempts} attempts left:"
        )
        self.target_word = self.choose_word()
        self.eligible_word_list = list(self.word_list)
        self.entry.configure(state="normal")
        self.button.configure(state="normal")
        self.eligible_label.config(
            text=f"Eligible words left: {len(self.eligible_word_list)}"
        )
        self.guessVar.set("")

    def open_word_definition(self, word):
        """Opens the word's definition in a web browser."""
        url = f"https://www.merriam-webster.com/dictionary/{word}"
        webbrowser.open(url)

    def guess_word(self):
        """Processes the user's guess."""
        word = self.target_word
        guess = self.guessVar.get().lower()
        end_game = False

        if len(guess) != self.word_length:  # Check if the guess is n letters long
            self.resultText.config(state="normal")  # Enable editing
            self.resultText.delete("1.0", "end")
            self.resultText.insert(
                "1.0",
                f"Please enter a valid {self.word_length} letter word!",
                "center",
            )
            self.resultText.config(state="disabled")  # Make it read-only
            return  # stop here

        if self.block_old_guesses and guess in self.previous_guesses:
            self.resultText.config(state="normal")  # Enable editing
            self.resultText.delete("1.0", "end")
            self.resultText.insert("1.0", "You already guessed this word!", "center")
            self.resultText.config(state="disabled")  # Make it read-only
            return

        self.previous_guesses.append(guess)  # only add if the word is good

        if guess == word:
            colors = self.evaluate_guess(word, guess)
            self.label.config(
                text=f"Score: " + str(self.attempts_init - self.attempts + 1)
            )
            self.resultText.config(state="normal")  # Enable editing
            self.resultText.delete("1.0", "end")
            self.resultText.insert("1.0", "You won!", "center")
            self.resultText.config(state="disabled")  # Make it read-only
            end_game = True
        elif self.attempts > 0 and not self.is_valid_guess(guess):
            self.resultText.config(state="normal")  # Enable editing
            self.resultText.delete("1.0", "end")
            self.resultText.insert(
                "1.0",
                f"Please enter a valid {self.word_length} letter word!",
                "center",
            )
            self.resultText.config(state="disabled")  # Make it read-only
        else:
            colors = self.evaluate_guess(word, guess)
            self.eligible_word_list = self.filter_word_list(guess, colors)
            self.eligible_label.config(
                text=f"Eligible words left: {len(self.eligible_word_list)}"
            )
            self.attempts -= 1
            self.label.config(
                text=f"Guess the word, you have {self.attempts} attempts left:"
            )

        if self.attempts == 0:
            word = word.upper()

            self.resultText.config(state="normal")  # Enable editing
            self.resultText.delete("1.0", "end")

            # Insert the initial text
            self.resultText.insert("1.0", "You Lost! Correct word: ", "center")

            # Insert the word as a tag
            self.resultText.insert("end", word, ("link", "center"))

            # Configure the tag
            self.resultText.tag_config("link", foreground="blue", underline=True)

            # Bind the click event to the tag
            self.resultText.tag_bind(
                "link", "<Button-1>", lambda event, w=word: self.open_word_definition(w)
            )
            self.resultText.config(state="disabled")  # Make it read-only

            end_game = True

        if end_game:
            self.entry.configure(state="disabled")
            self.button.configure(state="disabled")


if __name__ == "__main__":
    root = Tk()
    root.option_add("*Font", "Roboto 13")
    root.title("Lexodle")
    root.geometry("400x350")
    app = GameWindow(root)
    root.mainloop()
