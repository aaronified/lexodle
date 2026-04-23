import random
import pandas as pd
from tkinter import *
import webbrowser
import json
import os
import subprocess


def load_config():
    """Load configuration from config.json."""
    try:
        with open("./config.json", "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return {
            "default_word_length": 5,
            "default_attempts": 6,
            "block_old_guesses": True,
            "available_word_lengths": [5],
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
        self.block_old_guesses = self.config["block_old_guesses"]
        self.available_word_lengths = self.config["available_word_lengths"]
        self.dictionary_file_pattern = self.config["dictionary_file_pattern"]

        self.attempts = self.attempts_init
        self.word_usage_df = self.get_word_list()
        self.valid_words = set(self.word_usage_df["word"].str.lower())
        self.target_word, self.target_row = self.choose_word()
        self.eligible_word_list = list(self.word_usage_df["word"].values)
        self.guess_rows = []
        self.previous_guesses = []
        self.createWidgets()
        self.audio_player_process = None
        self.ffmpeg_location = "C:/ffmpeg-2024-12-04/bin"

    def get_word_list(self):
        """Returns the entire word dataset as a DataFrame."""
        filename = self.dictionary_file_pattern.format(length=self.word_length)
        try:
            word_usage_df = pd.read_csv(f"./{filename}")
            return word_usage_df
        except FileNotFoundError:
            print(f"Error: Required file not found. Check path ('./{filename}').")
            return pd.DataFrame()
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
            return pd.DataFrame()

    def load_word_list_for_length(self, word_length):
        """Load word list for a specific word length."""
        self.word_length = word_length
        self.word_usage_df = self.get_word_list()
        self.valid_words = set(self.word_usage_df["word"].str.lower())

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
        """Chooses a random word with weighted probability based on wordcount."""
        if self.word_usage_df.empty:
            return "", None  # Return empty string and None if DataFrame is empty

        # Extract words and their counts
        words = self.word_usage_df["word"].tolist()
        word_counts = self.word_usage_df["wordcount"].tolist()

        # Normalize word counts to create weights
        total_count = sum(word_counts)
        weights = [count / total_count for count in word_counts]

        # Choose a word based on the weights
        chosen_word = random.choices(words, weights=weights, k=1)[0]
        # chosen_word = 'otter'

        # Get the row for the chosen word
        chosen_row = self.word_usage_df[self.word_usage_df["word"] == chosen_word].iloc[
            0
        ]

        return chosen_word, chosen_row

    def createWidgets(self):
        """Creates the UI widgets."""
        menubar = Menu(self.master)
        self.master.config(menu=menubar)

        settings_menu = Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Settings", menu=settings_menu)

        settings_menu.add_command(label="New Game", command=self.reset_game)

        word_length_menu = Menu(settings_menu, tearoff=0)
        settings_menu.add_cascade(label="Word Length", menu=word_length_menu)
        for length in self.available_word_lengths:
            word_length_menu.add_command(
                label=f"{length} letters",
                command=lambda l=length: self.change_word_length(l),
            )

        attempts_menu = Menu(settings_menu, tearoff=0)
        settings_menu.add_cascade(label="Attempts", menu=attempts_menu)
        for attempts in [4, 5, 6, 7, 8]:
            attempts_menu.add_command(
                label=f"{attempts} attempts",
                command=lambda a=attempts: self.change_attempts(a),
            )

        self.guessVar = StringVar()
        self.resetButton = Button(self, text="New Game", command=self.reset_game)
        self.resetButton.pack()
        self.label = Label(
            self,
            text=f"Guess the {self.word_length}-letter word, you have {self.attempts} attempts left:",
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

        # Frame for word info (initially hidden)
        self.word_info_frame = Frame(self)
        # self.word_info_frame.pack() # removed pack

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
        target_counts = {}  # Count of each letter in the target word
        guess_counts = {}  # Count of each letter in the guess word

        # Initialize target_counts
        for char in word:
            target_counts[char] = target_counts.get(char, 0) + 1

        # Initialize guess_counts
        for char in guess:
            guess_counts[char] = guess_counts.get(char, 0) + 1

        # First pass: Mark greens
        for i, char in enumerate(guess):
            if char == word[i]:
                label = self.create_label(char, "#C6F4D6")  # Light green
                evaluation_colors.append("#C6F4D6")
                result.append(label)
                target_counts[char] -= 1
                guess_counts[char] -= 1
            else:
                result.append(None)  # Placeholder for non-green letters
                evaluation_colors.append(None)

        # Second pass: Mark yellows and reds
        for i, char in enumerate(guess):
            if result[i] is None:  # Only process non-green letters
                if (
                    char in target_counts
                    and target_counts[char] > 0
                    and guess_counts[char] > 0
                ):
                    label = self.create_label(char, "#F7DC6F")  # Light yellow
                    evaluation_colors[i] = "#F7DC6F"
                    target_counts[char] -= 1
                    guess_counts[char] -= 1
                else:
                    label = self.create_label(char, "#FFC5C5")  # Light red
                    evaluation_colors[i] = "#FFC5C5"
                result[i] = label

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
        self.resultText.config(state="normal")
        self.resultText.delete("1.0", "end")
        self.resultText.config(state="disabled")
        for row in self.guess_rows:
            row.destroy()
        self.guess_rows = []
        self.previous_guesses = []
        self.label.config(
            text=f"Guess the {self.word_length}-letter word, you have {self.attempts} attempts left:"
        )
        self.target_word, self.target_row = self.choose_word()
        self.eligible_word_list = list(self.word_usage_df["word"].values)
        self.entry.configure(state="normal")
        self.button.configure(state="normal")
        self.eligible_label.config(
            text=f"Eligible words left: {len(self.eligible_word_list)}"
        )
        self.guessVar.set("")
        self.clear_word_info()
        if self.word_info_frame.winfo_manager():
            self.word_info_frame.pack_forget()
        self.stop_audio()

    def change_word_length(self, length):
        """Change word length and restart game."""
        self.word_length = length
        self.load_word_list_for_length(length)
        self.reset_game()

    def change_attempts(self, attempts):
        """Change number of attempts and restart game."""
        self.attempts_init = attempts
        self.reset_game()

    def open_word_definition(self, word):
        """Opens the word's definition in a web browser."""
        url = f"https://www.merriam-webster.com/dictionary/{word}"
        webbrowser.open(url)

    def play_audio(self, audio_path):
        """Plays the audio file using the default system player."""
        self.stop_audio()  # Stop any currently playing audio

        absolute_audio_path = os.path.abspath(audio_path)

        if os.path.exists(absolute_audio_path):
            try:
                if os.name == "nt":  # Windows
                    # Use ffplay for Windows (you might need to install ffmpeg)
                    self.audio_player_process = subprocess.Popen(
                        [
                            os.path.join(self.ffmpeg_location, "ffplay"),
                            "-nodisp",
                            "-autoexit",
                            absolute_audio_path,
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                elif os.name == "posix":  # macOS or Linux
                    # Use ffplay for macOS/Linux (you might need to install ffmpeg)
                    self.audio_player_process = subprocess.Popen(
                        [
                            os.path.join(self.ffmpeg_location, "ffplay"),
                            "-nodisp",
                            "-autoexit",
                            absolute_audio_path,
                        ],
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                else:
                    print("Unsupported operating system for playing audio.")
            except FileNotFoundError:
                print(
                    "Error: ffplay not found. Please ensure ffmpeg is installed and in your PATH."
                )
            except Exception as e:
                print(f"Error playing audio: {e}")
        else:
            print(f"Audio file not found: {absolute_audio_path}")

    def stop_audio(self):
        """Stops the currently playing audio."""
        if self.audio_player_process:
            self.audio_player_process.terminate()
            self.audio_player_process = None

    def clear_word_info(self):
        """Clears the word info frame."""
        for widget in self.word_info_frame.winfo_children():
            widget.destroy()

    def display_word_info(self, row):
        """Displays word information (phonetics, definitions, etc.)."""
        self.clear_word_info()

        # Phonetics
        phonetics_label = Label(
            self.word_info_frame, text="Phonetics:", font=("Roboto", 12, "bold")
        )
        phonetics_label.pack()
        try:
            phonetics_data = json.loads(row["phonetics"])
            for phonetic in phonetics_data:
                phonetic_text = phonetic.get("text", "")
                Label(self.word_info_frame, text=f"- {phonetic_text}").pack()
        except json.JSONDecodeError:
            Label(self.word_info_frame, text="Error decoding phonetics data.").pack()

        # Definitions
        definitions_label = Label(
            self.word_info_frame, text="Definitions:", font=("Roboto", 12, "bold")
        )
        definitions_label.pack()
        try:
            meanings_data = json.loads(row["meanings"])
            for meaning in meanings_data:
                part_of_speech = meaning.get("partOfSpeech", "")
                Label(
                    self.word_info_frame,
                    text=f"  {part_of_speech}:",
                    font=("Roboto", 10, "bold"),
                ).pack()
                for definition in meaning.get("definitions", []):
                    def_text = definition.get("definition", "")
                    example = definition.get("example", "")
                    Label(self.word_info_frame, text=f"    - {def_text}").pack()
                    if example:
                        Label(
                            self.word_info_frame, text=f"      (e.g., {example})"
                        ).pack()

                # Synonyms and Antonyms
                synonyms = meaning.get("synonyms", [])
                antonyms = meaning.get("antonyms", [])
                if synonyms:
                    Label(
                        self.word_info_frame,
                        text=f"    Synonyms: {', '.join(synonyms)}",
                    ).pack()
                if antonyms:
                    Label(
                        self.word_info_frame,
                        text=f"    Antonyms: {', '.join(antonyms)}",
                    ).pack()
        except json.JSONDecodeError:
            Label(self.word_info_frame, text="Error decoding definitions data.").pack()

        # Audio Button
        audio_path = row.get("audio", "")
        if audio_path and os.path.exists(audio_path):
            audio_button = Button(
                self.word_info_frame,
                text="Play Audio",
                command=lambda: self.play_audio(audio_path),
            )
            audio_button.pack()

        self.word_info_frame.pack()

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
                text=f"Guess the {self.word_length}-letter word, you have {self.attempts} attempts left:"
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
            self.display_word_info(self.target_row)  # only show when end_game is True
        else:
            if self.word_info_frame.winfo_manager():
                self.word_info_frame.pack_forget()


if __name__ == "__main__":
    root = Tk()
    root.option_add("*Font", "Roboto 13")
    root.title("Lexodle")
    root.geometry("400x650")
    app = GameWindow(root)
    root.mainloop()
