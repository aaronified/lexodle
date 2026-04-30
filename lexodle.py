import random
import pandas as pd
from tkinter import *
import webbrowser
import json
import os
import subprocess
from lexodle_metrics import MetricsEngine


def load_config():
    """
    Load configuration from config.json file.
    
    This function attempts to read the configuration file from the current directory.
    If the file doesn't exist, it returns a default configuration dictionary.
    
    Returns:
        dict: Configuration dictionary containing:
            - default_word_length (int): The default number of letters for the word to guess
            - default_attempts (int): The default number of attempts allowed
             - block_old_guesses (bool): Whether to prevent re-guessing the same word
             - available_word_lengths (list): List of available word lengths to choose from
             - dictionary_file (str): The CSV dictionary filename (unified, with lettercount column)
    
    Variables:
        f (file object): The file handle for reading the JSON configuration file
    """
    try:
        with open("./config.json", "r") as f:
            return json.load(f)
    except FileNotFoundError:
        return {
            "default_word_length": 5,
            "default_attempts": 6,
            "block_old_guesses": True,
            "available_word_lengths": [5],
            "dictionary_file": "lexodle_list.csv",
        }


class GameWindow(Frame):
    def __init__(self, master=None):
        """
        Initializes a new GameWindow object and sets up the game state.
        
        This constructor initializes all game state variables, loads configuration,
        sets up the word list, chooses a target word, and creates the UI widgets.
        
        Args:
            master (Tk): The parent Tkinter window/widget
        
        Variables:
            self.master (Tk): Reference to the parent Tkinter window
            self.config (dict): Configuration dictionary loaded from config.json
            self.word_length (int): Current word length for the game (number of letters)
            self.attempts_init (int): Initial number of attempts allowed (from config)
            self.attempts (int): Current remaining attempts (decremented as player guesses)
            self.block_old_guesses (bool): If True, prevents player from guessing the same word twice
            self.available_word_lengths (list): List of available word lengths user can select
            self.dictionary_file (str): CSV dictionary filename (unified with lettercount column)
            self.word_usage_df (DataFrame): Pandas DataFrame containing words and their usage counts
            self.valid_words (set): Set of valid words (lowercase) for O(1) lookup during validation
            self.target_word (str): The secret word the player needs to guess
            self.target_row (Series): The DataFrame row containing target word's metadata (definitions, phonetics, etc.)
            self.eligible_word_list (list): List of words that still match the current guess pattern (for filtering)
            self.guess_rows (list): List of Frame widgets containing previous guess evaluations
            self.previous_guesses (list): List of previously guessed words (to block duplicates if enabled)
            self.audio_player_process (Popen or None): Reference to the subprocess playing audio (if any)
            self.ffmpeg_location (str): Filesystem path to the ffmpeg binary directory
            self.metrics_engine (MetricsEngine): Engine for computing skill/luck metrics
            self.guess_metrics (list): Per-guess metrics dicts with skill/luck scores
            self.show_metrics_mode (StringVar): Tkinter variable controlling metrics display mode
        """
        Frame.__init__(self, master)
        self.master = master
        self.pack()

        self.config = load_config()
        self.word_length = self.config["default_word_length"]
        self.attempts_init = self.config["default_attempts"]
        self.block_old_guesses = self.config["block_old_guesses"]
        self.available_word_lengths = self.config["available_word_lengths"]
        self.dictionary_file = self.config["dictionary_file"]

        self.attempts = self.attempts_init
        self.word_usage_df = self.get_word_list()
        self.valid_words = set(self.word_usage_df["word"].str.lower())
        self.target_word, self.target_row = self.choose_word()
        self.eligible_word_list = list(self.word_usage_df["word"].values)
        self.guess_rows = []
        self.previous_guesses = []
        self.invalid_guesses = set()
        self.metrics_engine = MetricsEngine(self.word_length, self.dictionary_file)
        self.guess_metrics = []
        self.show_metrics_mode = StringVar(value="after_each")
        self.createWidgets()
        self.audio_player_process = None
        self.ffmpeg_location = "C:/ffmpeg-2024-12-04/bin"

    def get_word_list(self):
        """
        Loads and returns the word dataset as a pandas DataFrame.

        Loads the unified dictionary file specified by self.dictionary_file.
        If the DataFrame contains a 'lettercount' column, filters rows where
        lettercount equals self.word_length. Otherwise, filters by word length.

        Returns:
            DataFrame: A pandas DataFrame containing the word list with columns like
                      'word', 'wordcount', 'phonetics', 'meanings', 'audio', etc.
                      Returns an empty DataFrame if loading fails.

        Variables:
            filename (str): The CSV dictionary filename from config (e.g., "lexodle_list.csv")
            word_usage_df (DataFrame): The loaded DataFrame containing all words and their metadata
            e (Exception): Exception object caught if an unexpected error occurs during file reading
        """
        filename = self.dictionary_file
        try:
            word_usage_df = pd.read_csv(f"./{filename}")
            # Filter by lettercount column if present, otherwise by word length
            if "lettercount" in word_usage_df.columns:
                word_usage_df = word_usage_df[word_usage_df["lettercount"] == self.word_length]
            else:
                word_usage_df = word_usage_df[word_usage_df["word"].str.len() == self.word_length]
            return word_usage_df.reset_index(drop=True)
        except FileNotFoundError:
            print(f"Error: Required file not found. Check path ('./{filename}').")
            return pd.DataFrame()
        except Exception as e:
            print(f"An unexpected error occurred: {e}")
            return pd.DataFrame()

    def load_word_list_for_length(self, word_length):
        """
        Loads the word list for a specific word length and updates valid words set.
        
        This method is called when the user changes the word length from the menu.
        It updates the word_length attribute, reloads the word list DataFrame,
        and recreates the valid_words set for fast lookup.
        
        Args:
            word_length (int): The new word length to load (e.g., 4, 5, 6, etc.)
        
        Variables:
            self.word_length (int): Updated to the new word length
            self.word_usage_df (DataFrame): Reloaded DataFrame for the new word length
            self.valid_words (set): Rebuilt set of valid words (lowercase) for O(1) validation
        """
        self.word_length = word_length
        self.word_usage_df = self.get_word_list()
        self.valid_words = set(self.word_usage_df["word"].str.lower())

    def is_valid_guess(self, guess):
        """
        Checks if the guess is a valid word using O(1) set lookup.
        
        Converts the guess to lowercase and checks if it exists in the valid_words set.
        Using a set provides O(1) average-case lookup time compared to O(n) for lists.
        
        Args:
            guess (str): The player's guessed word
            
        Returns:
            bool: True if the guess is a valid word in the dictionary, False otherwise
        
        Variables:
            guess.lower() (str): The lowercase version of the guess for case-insensitive comparison
            self.valid_words (set): Pre-computed set of all valid words in lowercase
        """
        return guess.lower() in self.valid_words

    def create_label(self, text, color):
        """
        Creates a styled Tkinter Label widget for displaying a guessed letter.
        
        Creates a label with the specified text (converted to uppercase) and background color.
        Used to display each letter in the guess with color-coded feedback.
        
        Args:
            text (str): The letter text to display in the label
            color (str): The background color hex code (e.g., "#C6F4D6" for green,
                        "#F7DC6F" for yellow, "#FFC5C5" for red)
        
        Returns:
            Label: A configured Tkinter Label widget
        
        Variables:
            text.upper() (str): The uppercase version of the input text for display
            bg (str): Background color of the label (indicates guess accuracy)
            width (int): Fixed width of the label (3 characters)
            borderwidth (float): Width of the label's border
            relief (str): Border style ("solid" for visible borders)
        """
        return Label(
            self.master,
            text=text.upper(),
            bg=color,
            width=3,
            borderwidth=0.1,
            relief="solid",
        )

    def choose_word(self):
        """
        Chooses a random word with weighted probability based on word usage count.
        
        Uses the wordcount column from the DataFrame to assign probabilities to each word.
        Words with higher usage counts have a higher chance of being selected.
        Returns both the chosen word and its corresponding DataFrame row (with metadata).
        
        Returns:
            tuple: (chosen_word (str), chosen_row (Series)) - The selected word and its data row.
                   Returns ("", None) if the DataFrame is empty.
        
        Variables:
            words (list): List of all words extracted from the 'word' column of the DataFrame
            word_counts (list): List of usage counts extracted from the 'wordcount' column
            total_count (int/float): Sum of all word counts, used for normalization
            weights (list): Normalized probabilities for each word (each weight = count/total_count)
            chosen_word (str): The randomly selected word based on weighted probability
            chosen_row (Series): The DataFrame row containing all metadata for the chosen word
                                (including phonetics, meanings, audio path, etc.)
        """
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
        """
        Creates and configures all the UI widgets for the game window.
        
        This method sets up the menu bar, game controls, input fields, display areas,
        and information panels. It's called once during initialization.
        
        Variables:
            menubar (Menu): The main menu bar attached to the master window
            settings_menu (Menu): Dropdown menu for game settings
            word_length_menu (Menu): Submenu for selecting word length
            length (int): Iterator variable for available word lengths in the menu
            attempts_menu (Menu): Submenu for selecting number of attempts
            attempts (int): Iterator variable for attempt options (4-8) in the menu
            l (int): Default parameter in lambda for word length callback
            a (int): Default parameter in lambda for attempts callback
            self.guessVar (StringVar): Tkinter variable linked to the entry widget for guess input
            self.resetButton (Button): Button to start a new game
            self.label (Label): Label displaying the current game status (word length and attempts)
            self.entry (Entry): Text input field where the player types their guess
            self.button (Button): Button to submit the guess
            self.resultText (Text): Read-only text widget for displaying game messages (win/lose/error)
            self.guesses_frame (Frame): Container frame for displaying all guess evaluation rows
            self.eligible_label (Label): Label showing how many words still match the current pattern
            self.word_info_frame (Frame): Hidden frame that displays word definitions when game ends
        """
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

        metrics_menu = Menu(settings_menu, tearoff=0)
        settings_menu.add_cascade(label="Metrics", menu=metrics_menu)
        for mode, label in [("after_each", "After Each (inline)"), ("end_only", "End Only"), ("skill_during", "Skill During, Luck at End"), ("off", "Off")]:
            metrics_menu.add_radiobutton(
                label=label,
                variable=self.show_metrics_mode,
                value=mode,
                command=lambda m=mode: self.change_metrics_mode(m),
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

        self.metrics_label = Label(self, text="", justify="left")
        self.metrics_label.pack()

        # Frame for word info (initially hidden)
        self.word_info_frame = Frame(self)
        # self.word_info_frame.pack() # removed pack

    def validate_input(self, event):
        """
        Validates and modifies the input in the Entry widget as the user types.
        
        This method is bound to the <KeyRelease> event. It filters out non-alphabetic
        characters, converts all letters to uppercase, and enforces the maximum length
        based on the current word length.
        
        Args:
            event (Event): The Tkinter key release event that triggered this callback
        
        Variables:
            current_value (str): The current text in the entry widget (before validation)
            new_value (str): The filtered and formatted text (only alphabetic chars, uppercase)
            char (str): Iterator variable representing each character in current_value
        """
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
        """
        Evaluates the player's guess against the target word and creates visual feedback.
        
        Implements the Wordle-style color-coding algorithm:
        - Green (#C6F4D6): Letter is correct and in the correct position
        - Yellow (#F7DC6F): Letter exists in target word but in wrong position
        - Red (#FFC5C5): Letter does not exist in target word
        
        Uses a two-pass approach with letter counts to handle duplicate letters correctly.
        
        Args:
            word (str): The target word to guess (self.target_word)
            guess (str): The player's guessed word (lowercase)
        
        Returns:
            list: A list of color hex codes corresponding to each letter position
        
        Variables:
            evaluation_labels (Frame): Container frame for this guess's letter labels
            result (list): List of Label widgets (or None placeholders) for each letter
            evaluation_colors (list): List of color hex codes for each letter position
            target_counts (dict): Counts of each letter in the target word (for tracking remaining matches)
            guess_counts (dict): Counts of each letter in the guess word (for tracking remaining matches)
            char (str): Iterator variable for each character in the guess word
            i (int): Index position of the current character in the guess
            label (Label): The created label widget for displaying a letter with color coding
        """
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
        """
        Filters the eligible word list based on the guess and its color evaluation.
        
        Removes words that don't match the clues from the player's guess:
        - Green letters must be in the exact same position
        - Yellow letters must be in the word but NOT in that position
        - Red letters must NOT be anywhere in the word
        
        This helps narrow down the possible words for the player.
        
        Args:
            guess (str): The player's guessed word
            evaluation (list): List of color hex codes from evaluate_guess()
        
        Returns:
            list: Filtered list of words that match all the clues from the guess
        
        Variables:
            new_word_list (list): Accumulator for words that pass all filter criteria
            word (str): Iterator variable for each word in the eligible word list
            valid (bool): Flag indicating whether the current word matches all criteria
            i (int): Index position of the current character being evaluated
            char (str): The character at position i in the guess word
        """
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
        """
        Resets the game state to start a new game.
        
        This method is called when the player starts a new game (via menu or button).
        It resets all game variables, clears the UI, chooses a new target word,
        and stops any playing audio.
        
        Variables:
            row (Frame): Iterator variable for each guess row frame to be destroyed
            self.attempts (int): Reset to initial number of attempts
            self.guess_rows (list): Cleared after destroying all row widgets
            self.previous_guesses (list): Cleared to allow fresh guesses
            self.target_word (str): New randomly chosen word for the new game
            self.target_row (Series): Data row for the new target word
            self.eligible_word_list (list): Reset to full word list from DataFrame
        """
        self.attempts = self.attempts_init
        self.resultText.config(state="normal")
        self.resultText.delete("1.0", "end")
        self.resultText.config(state="disabled")
        # Destroy all children of guesses_frame (guess rows and inline metrics)
        for child in self.guesses_frame.winfo_children():
            child.destroy()
        self.guess_rows = []
        self.previous_guesses = []
        self.invalid_guesses = set()
        self.guess_metrics = []
        self.label.config(
            text=f"Guess the {self.word_length}-letter word, you have {self.attempts} attempts left:"
        )
        self.target_word, self.target_row = self.choose_word()
        self.eligible_word_list = list(self.word_usage_df["word"].values)
        self.metrics_engine = MetricsEngine(self.word_length, self.dictionary_file)
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
        """
        Changes the word length setting and restarts the game.
        
        Called when the user selects a new word length from the Settings menu.
        Updates the word length, reloads the appropriate word list, and resets the game.
        
        Args:
            length (int): The new word length selected by the user
        
        Variables:
            self.word_length (int): Updated to the new length
        """
        self.word_length = length
        self.load_word_list_for_length(length)
        self.metrics_engine = MetricsEngine(self.word_length, self.dictionary_file)
        self.reset_game()

    def change_attempts(self, attempts):
        """
        Changes the number of attempts allowed and restarts the game.
        
        Called when the user selects a new number of attempts from the Settings menu.
        Updates the initial attempts value and resets the game with the new setting.
        
        Args:
            attempts (int): The new number of attempts selected by the user (4-8)
        
        Variables:
            self.attempts_init (int): Updated to the new number of attempts
        """
        self.attempts_init = attempts
        self.reset_game()

    def change_metrics_mode(self, mode):
        """
        Changes the metrics display mode.

        Args:
            mode (str): The new display mode
        """
        self.show_metrics_mode.set(mode)
        self.update_metrics_summary()

    def display_guess_metrics(self, skill, luck, eligible_before, eligible_after):
        """
        Returns a formatted metrics string for inline display.

        Args:
            skill (float): Skill score
            luck (float): Luck score
            eligible_before (int): Words before guess
            eligible_after (int): Words after guess

        Returns:
            str: Formatted metrics string or empty string
        """
        mode = self.show_metrics_mode.get()
        if mode == "off":
            return ""
        parts = []
        if mode == "after_each" or mode == "skill_during":
            parts.append(f"Skill: {skill:.1f}")
        if mode == "after_each":
            parts.append(f"Luck: {luck:.1f}")
        parts.append(f"Words: {eligible_before}→{eligible_after}")
        return " | ".join(parts)

    def update_metrics_on_guess(self, guess, eligible_before_list, eligible_after_list, correct=False):
        """
        Updates metrics after a guess.

        Args:
            guess (str): The guessed word
            eligible_before_list (list): Eligible words before guess
            eligible_after_list (list): Eligible words after guess
            correct (bool): Whether guess was correct
        """
        mask_before = self.metrics_engine.get_eligible_mask(eligible_before_list)
        mask_after = self.metrics_engine.get_eligible_mask(eligible_after_list)
        N_before = bin(mask_before).count("1")
        N_after = bin(mask_after).count("1")

        skill = 0.0
        luck = 0.0

        guess_lower = guess.lower()
        if guess_lower in self.metrics_engine.guess_partitions and N_before > 0:
            partitions = self.metrics_engine.guess_partitions[guess_lower]
            total_size_sq = 0
            total_count = 0
            for pattern, partition_mask in partitions.items():
                eligible_partition = partition_mask & mask_before
                size = bin(eligible_partition).count("1")
                if size > 0:
                    total_size_sq += size * size
                    total_count += size

            if total_count > 0:
                expected_n = total_size_sq / N_before
                if N_before <= 1:
                    skill = 100.0
                else:
                    skill = (N_before - expected_n) / (N_before - 1) * 100.0
                if N_before - expected_n != 0:
                    luck = (N_before - N_after) / (N_before - expected_n) * 100.0

        self.guess_metrics.append({
            "guess": guess,
            "skill": skill,
            "luck": luck,
            "before": N_before,
            "after": N_after,
            "correct": correct,
        })
        self.update_metrics_summary()

    def update_metrics_summary(self):
        """
        Updates the summary metrics label.
        """
        mode = self.show_metrics_mode.get()
        if mode == "off":
            self.metrics_label.config(text="")
            return
        game_over = str(self.entry['state']) == 'disabled'
        if game_over and mode in ("end_only", "skill_during"):
            if self.guess_metrics:
                total_skill = sum(m["skill"] for m in self.guess_metrics) / len(self.guess_metrics)
                total_luck = sum(m["luck"] for m in self.guess_metrics) / len(self.guess_metrics)
                self.metrics_label.config(text=f"Cumulative — Skill: {total_skill:.1f} | Luck: {total_luck:.1f}")
            else:
                self.metrics_label.config(text="")
        else:
            self.metrics_label.config(text="")

    def display_inline_metrics(self, metrics_str):
        """
        Displays inline metrics below the current guess row.

        Args:
            metrics_str (str): Formatted metrics string
        """
        if metrics_str:
            label = Label(self.guesses_frame, text=metrics_str, justify="left")
            label.pack()

    def open_word_definition(self, word):
        """
        Opens the word's definition in the default web browser.
        
        Constructs a URL to Merriam-Webster's online dictionary and opens it
        in the user's default web browser.
        
        Args:
            word (str): The word to look up (typically the target word when game ends)
        
        Variables:
            url (str): The complete URL to the word's definition page
        """
        url = f"https://www.merriam-webster.com/dictionary/{word}"
        webbrowser.open(url)

    def play_audio(self, audio_path):
        """
        Plays the audio file using ffplay (from ffmpeg) in the background.
        
        Stops any currently playing audio before starting the new audio.
        Uses ffplay with -nodisp (no GUI window) and -autoexit (exit when done).
        Works on Windows (nt) and Unix-based systems (posix).
        
        Args:
            audio_path (str): Relative or absolute path to the audio file to play
        
        Variables:
            absolute_audio_path (str): Absolute path to the audio file (for reliable access)
            os.name (str): System identifier ("nt" for Windows, "posix" for Unix-like)
            self.audio_player_process (Popen): Subprocess handle for the ffplay process
            self.ffmpeg_location (str): Directory path where ffplay executable is located
            e (Exception): Caught exception if ffplay is not found or fails to run
        """
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
        """
        Stops the currently playing audio process if one exists.
        
        Terminates the ffplay subprocess and resets the process reference to None.
        Safe to call even if no audio is currently playing.
        
        Variables:
            self.audio_player_process (Popen or None): Reference to the running ffplay process
        """
        if self.audio_player_process:
            self.audio_player_process.terminate()
            self.audio_player_process = None

    def clear_word_info(self):
        """
        Clears all widgets from the word info frame.
        
        Destroys all child widgets in the word_info_frame to prepare for
        displaying new word information or hiding the frame.
        
        Variables:
            widget (Widget): Iterator variable for each child widget in the frame
        """
        for widget in self.word_info_frame.winfo_children():
            widget.destroy()

    def display_word_info(self, row):
        """
        Displays detailed word information in the word_info_frame.
        
        Shows phonetics, definitions with examples, synonyms, antonyms, and
        an audio playback button (if audio file exists). This is displayed when the game ends.
        
        Args:
            row (Series): The DataFrame row containing the target word's metadata
        
        Variables:
            phonetics_label (Label): Header label for the phonetics section
            phonetics_data (list): Parsed JSON list of phonetic representations
            phonetic (dict): Individual phonetic entry with 'text' and 'audio' keys
            phonetic_text (str): The phonetic text representation (e.g., "/wɜːrd/")
            definitions_label (Label): Header label for the definitions section
            meanings_data (list): Parsed JSON list of meaning objects from the dictionary
            meaning (dict): Individual meaning with partOfSpeech and definitions
            part_of_speech (str): The grammatical category (noun, verb, etc.)
            definition (dict): Individual definition entry with text and optional example
            def_text (str): The definition text
            example (str): Example sentence using the word (may be empty)
            synonyms (list): List of synonym words for this meaning
            antonyms (list): List of antonym words for this meaning
            audio_path (str): Path to the audio pronunciation file
            audio_button (Button): Button to play the word's audio pronunciation
        """
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
        if pd.isna(audio_path):
            audio_path = ""
        elif not isinstance(audio_path, str):
            audio_path = str(audio_path)
        if audio_path and os.path.exists(audio_path):
            audio_button = Button(
                self.word_info_frame,
                text="Play Audio",
                command=lambda: self.play_audio(audio_path),
            )
            audio_button.pack()

        self.word_info_frame.pack()

    def guess_word(self):
        """
        Processes the user's guess and updates the game state.

        This is the main game logic method. It validates the guess (length, duplicates),
        checks if the guess is correct, updates the UI with feedback, filters the eligible
        word list, and handles win/lose conditions. Also computes and displays metrics.

        Variables:
            word (str): The target word to guess (self.target_word)
            guess (str): The player's input guess, converted to lowercase
            end_game (bool): Flag indicating whether the game has ended (win or lose)
            colors (list): Color evaluation from evaluate_guess() for each letter position
            self.guessVar (StringVar): Tkinter variable containing the raw user input
            self.previous_guesses (list): Updated with the current guess if valid
            self.attempts (int): Decremented when the guess is incorrect
            self.eligible_word_list (list): Filtered based on the guess evaluation
            self.label (Label): Updated to show remaining attempts or final score
            self.resultText (Text): Updated with win/lose/error messages
            self.entry (Entry): Disabled when game ends
            self.button (Button): Disabled when game ends
        """
        word = self.target_word
        guess = self.guessVar.get().lower()
        end_game = False

        if len(guess) != self.word_length:
            self.resultText.config(state="normal")
            self.resultText.delete("1.0", "end")
            self.resultText.insert(
                "1.0",
                f"Please enter a valid {self.word_length} letter word!",
                "center",
            )
            self.resultText.config(state="disabled")
            return

        if self.block_old_guesses and guess in self.previous_guesses:
            self.resultText.config(state="normal")
            self.resultText.delete("1.0", "end")
            self.resultText.insert("1.0", "You already guessed this word!", "center")
            self.resultText.config(state="disabled")
            return

        eligible_before_list = self.eligible_word_list.copy()
        self.previous_guesses.append(guess)

        if guess == word:
            colors = self.evaluate_guess(word, guess)
            self.label.config(
                text=f"Score: " + str(self.attempts_init - self.attempts + 1)
            )
            self.resultText.config(state="normal")
            self.resultText.delete("1.0", "end")
            self.resultText.insert("1.0", "You won!", "center")
            self.resultText.config(state="disabled")
            end_game = True
            eligible_after_list = [word]
            self.update_metrics_on_guess(guess, eligible_before_list, eligible_after_list, correct=True)
            if self.show_metrics_mode.get() == "after_each":
                last = self.guess_metrics[-1]
                inline = self.display_guess_metrics(last["skill"], last["luck"], last["before"], last["after"])
                self.display_inline_metrics(inline)
            elif self.show_metrics_mode.get() == "skill_during":
                last = self.guess_metrics[-1]
                inline = f"Skill: {last['skill']:.1f} | Words: {last['before']}→{last['after']}"
                self.display_inline_metrics(inline)
        elif self.attempts > 0 and not self.is_valid_guess(guess):
            if guess in self.invalid_guesses:
                message = f"'{guess.upper()}' is not a valid word!"
            else:
                message = f"Please enter a valid {self.word_length} letter word!"
                self.invalid_guesses.add(guess)
            self.resultText.config(state="normal")
            self.resultText.delete("1.0", "end")
            self.resultText.insert("1.0", message, "center")
            self.resultText.config(state="disabled")
        else:
            colors = self.evaluate_guess(word, guess)
            self.eligible_word_list = self.filter_word_list(guess, colors)
            eligible_after_list = self.eligible_word_list
            self.eligible_label.config(
                text=f"Eligible words left: {len(eligible_after_list)}"
            )
            self.attempts -= 1
            self.label.config(
                text=f"Guess the {self.word_length}-letter word, you have {self.attempts} attempts left:"
            )
            self.update_metrics_on_guess(guess, eligible_before_list, eligible_after_list, correct=False)
            if self.show_metrics_mode.get() == "after_each":
                last = self.guess_metrics[-1]
                inline = self.display_guess_metrics(last["skill"], last["luck"], last["before"], last["after"])
                self.display_inline_metrics(inline)
            elif self.show_metrics_mode.get() == "skill_during":
                last = self.guess_metrics[-1]
                inline = f"Skill: {last['skill']:.1f} | Words: {last['before']}→{last['after']}"
                self.display_inline_metrics(inline)

        if self.attempts == 0:
            target_upper = word.upper()
            self.resultText.config(state="normal")
            self.resultText.delete("1.0", "end")
            self.resultText.insert("1.0", "You Lost! Correct word: ", "center")
            self.resultText.insert("end", target_upper, ("link", "center"))
            self.resultText.tag_config("link", foreground="blue", underline=True)
            self.resultText.tag_bind(
                "link", "<Button-1>", lambda event, w=word: self.open_word_definition(w)
            )
            self.resultText.config(state="disabled")
            end_game = True

        if end_game:
            self.entry.configure(state="disabled")
            self.button.configure(state="disabled")
            self.display_word_info(self.target_row)
            self.update_metrics_summary()


if __name__ == "__main__":
    """
    Main entry point of the Lexodle game application.
    
    Creates the Tkinter root window, configures global settings,
    instantiates the GameWindow, and starts the Tkinter event loop.
    
    Variables:
        root (Tk): The main Tkinter window instance
        app (GameWindow): The main game application frame
    """
    root = Tk()
    root.option_add("*Font", "Roboto 13")
    root.title("Lexodle")
    root.geometry("400x650")
    app = GameWindow(root)
    root.mainloop()
