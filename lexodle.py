import random
import pandas as pd
from tkinter import *
import ttkbootstrap as ttk
from ttkbootstrap.constants import *
import webbrowser
import json
import os
import subprocess
from lexodle_metrics import MetricsEngine
from theme import get_theme, set_theme_mode
from cell_widget import WordGrid, Keyboard
from settings_dialog import SettingsDialog


def load_config():
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


def get_available_word_lengths(csv_file):
    try:
        df = pd.read_csv(csv_file)
        if "lettercount" in df.columns:
            lengths = sorted(df["lettercount"].unique().tolist())
        else:
            df["length"] = df["word"].str.len()
            lengths = sorted(df["length"].unique().tolist())
        return lengths
    except Exception as e:
        print(f"Error reading CSV for available lengths: {e}")
        return [5]


def get_cache_dir_from_user(parent, default_dir="cache"):
    """Prompt user for cache directory location."""
    from tkinter import simpledialog
    d = CacheDirDialog(parent, default_dir)
    parent.wait_window(d.top)
    return d.result


class CacheDirDialog:
    def __init__(self, parent, default_dir):
        self.top = Toplevel(parent)
        self.top.title("Cache Directory")
        self.top.transient(parent)
        self.top.grab_set()
        self.top.resizable(False, False)
        
        # Center on parent
        parent_x = parent.winfo_x()
        parent_y = parent.winfo_y()
        parent_w = parent.winfo_width()
        parent_h = parent.winfo_height()
        w, h = 450, 200
        x = parent_x + (parent_w - w) // 2
        y = parent_y + (parent_h - h) // 2
        self.top.geometry(f"{w}x{h}+{x}+{y}")
        
        self.theme = get_theme()
        self.top.configure(bg=self.theme.bg_main)
        
        self.result = default_dir
        
        frame = Frame(self.top, bg=self.theme.bg_card, padx=24, pady=24)
        frame.place(relx=0.5, rely=0.5, anchor=CENTER)
        
        Label(
            frame,
            text="Cache Directory Location",
            font=(self.theme.font_family, self.theme.font_size_large, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.text_primary,
        ).pack(pady=(0, 8))
        
        Label(
            frame,
            text="Where should PKL cache files be stored?",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(pady=(0, 16))
        
        entry_frame = Frame(frame, bg=self.theme.bg_card)
        entry_frame.pack(fill=X, pady=(0, 16))
        
        self.entry_var = StringVar(value=default_dir)
        Entry(
            entry_frame,
            textvariable=self.entry_var,
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_input,
            fg=self.theme.text_primary,
            relief=FLAT,
            bd=0,
            highlightthickness=1,
            highlightbackground=self.theme.border_color,
            highlightcolor=self.theme.border_focus,
            insertbackground=self.theme.text_primary,
        ).pack(side=LEFT, fill=X, expand=True, ipady=4)
        
        Button(
            entry_frame,
            text="Browse...",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.btn_secondary_bg,
            fg=self.theme.btn_secondary_fg,
            relief=FLAT,
            bd=0,
            padx=12,
            pady=6,
            command=self.browse,
        ).pack(side=LEFT, padx=(8, 0))
        
        btn_frame = Frame(frame, bg=self.theme.bg_card)
        btn_frame.pack(fill=X)
        
        Button(
            btn_frame,
            text="Use Default",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.btn_secondary_bg,
            fg=self.theme.btn_secondary_fg,
            relief=FLAT,
            bd=0,
            padx=20,
            pady=8,
            command=self.use_default,
        ).pack(side=LEFT)
        
        Button(
            btn_frame,
            text="OK",
            font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            bg=self.theme.btn_primary_bg,
            fg=self.theme.btn_primary_fg,
            relief=FLAT,
            bd=0,
            padx=24,
            pady=8,
            command=self.confirm,
        ).pack(side=RIGHT)
    
    def browse(self):
        from tkinter import filedialog
        d = filedialog.askdirectory(title="Select Cache Directory", initialdir=self.entry_var.get())
        if d:
            self.entry_var.set(d)
    
    def use_default(self):
        self.entry_var.set("cache")
    
    def confirm(self):
        self.result = self.entry_var.get().strip()
        if not self.result:
            self.result = "cache"
        self.top.destroy()


class ProgressModal:
    def __init__(self, parent, title="Processing", message="Please wait..."):
        self.parent = parent
        self.theme = get_theme()
        
        self.overlay = Toplevel(parent)
        self.overlay.title(title)
        self.overlay.transient(parent)
        self.overlay.grab_set()
        self.overlay.resizable(False, False)
        
        self.overlay.configure(bg=self.theme.bg_card)
        
        parent_x = parent.winfo_x()
        parent_y = parent.winfo_y()
        parent_w = parent.winfo_width()
        parent_h = parent.winfo_height()
        w, h = 420, 160
        x = parent_x + (parent_w - w) // 2
        y = parent_y + (parent_h - h) // 2
        self.overlay.geometry(f"{w}x{h}+{x}+{y}")
        
        container = Frame(self.overlay, bg=self.theme.bg_card, padx=32, pady=24)
        container.pack(fill="both", expand=True)
        
        Label(
            container,
            text=title,
            font=(self.theme.font_family, self.theme.font_size_large, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.text_primary,
        ).pack(pady=(0, 4))
        
        self.message_label = Label(
            container,
            text=message,
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        )
        self.message_label.pack(pady=(0, 16))
        
        self.progress_var = DoubleVar(value=0)
        pb = ttk.Progressbar(
            container,
            variable=self.progress_var,
            maximum=100,
            mode="determinate",
            bootstyle="success-striped",
            length=380,
        )
        pb.pack(pady=(0, 8))
    
    def set_progress(self, value):
        self.progress_var.set(value)
        self.overlay.update_idletasks()
    
    def set_message(self, message):
        self.message_label.config(text=message)
        self.overlay.update_idletasks()
    
    def close(self):
        self.overlay.grab_release()
        self.overlay.destroy()


class GameWindow(Frame):
    def __init__(self, master=None):
        Frame.__init__(self, master)
        self.master = master
        self.pack(fill=BOTH, expand=True)
        
        self.theme = get_theme()
        
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
        self.previous_guesses = []
        self.invalid_guesses = set()
        self.guess_metrics = []
        self.debug_mode = False
        
        # Metrics engine with progress callback
        self.metrics_engine = None
        self.init_metrics_engine(progress_callback=self.progress_callback, parent=master)
        
        self.audio_player_process = None
        self.ffmpeg_location = "C:/ffmpeg-2024-12-04/bin"
        
        # THEME DISABLED - was causing issues
        # self.current_theme = "light"
        
        self.create_widgets()
        
        # Bind global key events
        self.master.bind("<Key>", self.global_key_handler)
    
    def init_metrics_engine(self, progress_callback=None, parent=None):
        """Initialize metrics engine, showing progress modal if generating PKL."""
        modal = ProgressModal(parent if parent else self.master, 
                              "Loading Metrics", 
                              "Preparing word partitions...")
        
        def wrapped_progress(pct, msg):
            modal.set_progress(pct)
            if msg:
                modal.set_message(msg)
        
        try:
            self.metrics_engine = MetricsEngine(
                self.word_length, 
                self.dictionary_file,
                progress_callback=wrapped_progress
            )
        finally:
            modal.close()
    
    def progress_callback(self, pct, msg):
        """Progress callback from MetricsEngine. Currently handled by wrapped version."""
        pass
    
    def get_word_list(self):
        filename = self.dictionary_file
        try:
            word_usage_df = pd.read_csv(f"./{filename}")
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
        self.word_length = word_length
        self.word_usage_df = self.get_word_list()
        self.valid_words = set(self.word_usage_df["word"].str.lower())
        # Re-init metrics for new length
        self.init_metrics_engine(progress_callback=self.progress_callback, parent=self.master)
    
    def is_valid_guess(self, guess):
        return guess.lower() in self.valid_words
    
    def choose_word(self):
        if self.word_usage_df.empty:
            return "", None
        words = self.word_usage_df["word"].tolist()
        word_counts = self.word_usage_df["wordcount"].tolist()
        total_count = sum(word_counts)
        weights = [count / total_count for count in word_counts]
        chosen_word = random.choices(words, weights=weights, k=1)[0]
        chosen_row = self.word_usage_df[self.word_usage_df["word"] == chosen_word].iloc[0]
        return chosen_word, chosen_row
    
    def create_widgets(self):
        # Main container with theme bg
        self.main_container = Frame(self, bg=self.theme.bg_main)
        self.main_container.pack(fill=BOTH, expand=True)
        
        # Header
        header = Frame(self.main_container, bg=self.theme.bg_header, height=70)
        header.pack(fill=X)
        header.pack_propagate(False)
        
        title_label = Label(
            header,
            text="LEXODLE",
            font=(self.theme.font_family, self.theme.font_size_xlarge, "bold"),
            bg=self.theme.bg_header,
            fg=self.theme.text_inverse,
        )
        title_label.pack(side=LEFT, padx=24)
        
        # THEME DISABLED - was causing issues
        # Theme toggle
        # self.theme_btn = Button(
        #     header,
        #     text="🌙" if self.current_theme == "light" else "☀️",
        #     font=("Segoe UI", 16),
        #     bg=self.theme.bg_header,
        #     fg=self.theme.text_inverse,
        #     activebackground=self.theme.bg_header,
        #     activeforeground=self.theme.text_inverse,
        #     relief=FLAT,
        #     bd=0,
        #     padx=12,
        #     pady=6,
        #     command=self.toggle_theme,
        # )
        # self.theme_btn.pack(side=RIGHT, padx=20)
        
        # Settings gear button
        settings_btn = Button(
            header,
            text="⚙",
            font=("Segoe UI", 14),
            bg=self.theme.bg_header,
            fg=self.theme.text_inverse,
            activebackground=self.theme.bg_header,
            activeforeground=self.theme.text_inverse,
            relief=FLAT,
            bd=0,
            padx=12,
            pady=6,
            command=self.open_settings,
        )
        settings_btn.pack(side=RIGHT, padx=(0, 8))
        
        # Content area
        content = Frame(self.main_container, bg=self.theme.bg_main)
        content.pack(fill=BOTH, expand=True, padx=24, pady=(16, 24))
        
        # Word length selector
        length_frame = Frame(content, bg=self.theme.bg_card, bd=0, relief=FLAT)
        length_frame.pack(fill=X, pady=(0, 16))
        
        Label(
            length_frame,
            text="Word Length:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(side=LEFT, padx=(16, 8))
        
        # Get truly available lengths from CSV
        csv_lengths = get_available_word_lengths(self.dictionary_file)
        self.length_buttons = {}
        for l in sorted(csv_lengths):
            state = NORMAL if l in self.available_word_lengths else DISABLED
            btn = Button(
                length_frame,
                text=str(l),
                font=(self.theme.font_family, self.theme.font_size_base, "bold"),
                width=3,
                bg=self.theme.btn_primary_bg if l == self.word_length else self.theme.btn_secondary_bg,
                fg=self.theme.text_inverse if l == self.word_length else (self.theme.btn_secondary_fg if state == NORMAL else "#666666"),
                relief=FLAT if l == self.word_length else RAISED,
                bd=0 if l == self.word_length else 2,
                padx=8,
                pady=6,
                command=lambda ll=l: self.change_word_length(ll),
            )
            btn.pack(side=LEFT, padx=2)
            self.length_buttons[l] = btn
        
        # Attempts selector
        attempts_frame = Frame(content, bg=self.theme.bg_card, bd=0, relief=FLAT)
        attempts_frame.pack(fill=X, pady=(0, 16))
        
        Label(
            attempts_frame,
            text="Attempts:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(side=LEFT, padx=(16, 8))
        
        self.attempts_buttons = {}
        for a in [4, 5, 6, 7, 8]:
            btn = Button(
                attempts_frame,
                text=str(a),
                font=(self.theme.font_family, self.theme.font_size_base, "bold"),
                width=3,
                bg=self.theme.btn_primary_bg if a == self.attempts_init else self.theme.btn_secondary_bg,
                fg=self.theme.text_inverse if a == self.attempts_init else self.theme.btn_secondary_fg,
                relief=FLAT if a == self.attempts_init else RAISED,
                bd=0 if a == self.attempts_init else 2,
                padx=8,
                pady=6,
                command=lambda aa=a: self.change_attempts(aa),
            )
            btn.pack(side=LEFT, padx=2)
            self.attempts_buttons[a] = btn
        
        # Stats row
        stats_frame = Frame(content, bg=self.theme.bg_card)
        stats_frame.pack(fill=X, pady=(0, 12))
        
        self.attempts_label = Label(
            stats_frame,
            text=f"{self.attempts} attempts left",
            font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.text_accent,
        )
        self.attempts_label.pack(side=LEFT)
        
        self.eligible_label = Label(
            stats_frame,
            text=f"{len(self.eligible_word_list)} eligible words",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        )
        self.eligible_label.pack(side=RIGHT)
        
        # Error/Warning message area (below attempts)
        self.error_label = Label(
            stats_frame,
            text="",
            font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.accent_error,
        )
        self.error_label.pack(pady=(4, 0))
        
        # Grid container
        grid_container = Frame(content, bg=self.theme.bg_card)
        grid_container.pack(pady=(8, 16))
        
        self.word_grid = WordGrid(
            grid_container,
            rows=6,
            cols=self.word_length,
            on_submit=self.handle_guess_submit,
        )
        self.word_grid.pack(pady=8)
        
        # Keyboard
        self.keyboard = Keyboard(content, on_key_click=self.handle_keyboard_click)
        self.keyboard.pack(pady=(0, 16))
        
        # Instructions
        Label(
            content,
            text="Click cells to type • Enter submits • ← Backspace deletes",
            font=(self.theme.font_family, self.theme.font_size_small),
            bg=self.theme.bg_main,
            fg=self.theme.text_secondary,
        ).pack(pady=(0, 12))
        
        # New game button
        self.new_game_btn = Button(
            content,
            text="New Game",
            font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            bg=self.theme.btn_primary_bg,
            fg=self.theme.btn_primary_fg,
            activebackground=self.theme.btn_primary_hover,
            activeforeground=self.theme.btn_primary_fg,
            relief=FLAT,
            bd=0,
            padx=24,
            pady=10,
            command=self.reset_game,
        )
        self.new_game_btn.pack(pady=(8, 16))
        
        # Metrics display area
        self.metrics_frame = Frame(content, bg=self.theme.bg_card)
        self.metrics_frame.pack(fill=X, pady=(8, 0))
        
        self.metrics_label = Label(
            self.metrics_frame,
            text="",
            font=(self.theme.font_family, self.theme.font_size_small),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
            justify=LEFT,
        )
        self.metrics_label.pack(anchor=W)
        
        # Result message area
        self.result_label = Label(
            content,
            text="",
            font=(self.theme.font_family, self.theme.font_size_large, "bold"),
            bg=self.theme.bg_main,
            fg=self.theme.text_accent,
        )
        self.result_label.pack(pady=(8, 16))
        
        # Word info frame (reveal)
        self.word_info_frame = Frame(content, bg=self.theme.bg_card)
        
        # Focus tracking
        self.master.bind("<FocusIn>", lambda e: self.word_grid.focus())
    
    # THEME DISABLED - was causing issues
    # def toggle_theme(self):
    #     self.current_theme = "dark" if self.current_theme == "light" else "light"
    #     set_theme_mode(self.current_theme)
    #     self.theme = get_theme()
    #     # Update tkinter default bg colors
    #     bg = self.theme.bg_main
    #     self.master.configure(bg=bg)
    #     self.main_container.configure(bg=bg)
    #     # Update theme button text
    #     self.theme_btn.config(text="🌙" if self.current_theme == "light" else "☀️")
    #     # Re-create UI with new theme
    #     self.refresh_ui_for_theme()
    # 
    # def refresh_ui_for_theme(self):
    #     # Rebuild the UI components with updated theme colors
    #     # This is a simplified refresh - just update widget colors
    #     self.word_grid.set_theme()
    #     
    #     # Update length buttons
    #     for l, btn in self.length_buttons.items():
    #         is_active = l == self.word_length
    #         is_available = l in self.available_word_lengths
    #         btn.config(
    #             bg=self.theme.btn_primary_bg if is_active else self.theme.btn_secondary_bg,
    #             fg=self.theme.text_inverse if is_active else (self.theme.btn_secondary_fg if is_available else "#666666"),
    #             relief=FLAT if is_active else RAISED,
    #             bd=0 if is_active else 2,
    #             state=NORMAL if is_available else DISABLED,
    #         )
    #     
    #     # Update attempts buttons  
    #     for a, btn in self.attempts_buttons.items():
    #         is_active = a == self.attempts_init
    #         btn.config(
    #             bg=self.theme.btn_primary_bg if is_active else self.theme.btn_secondary_bg,
    #             fg=self.theme.text_inverse if is_active else self.theme.btn_secondary_fg,
    #             relief=FLAT if is_active else RAISED,
    #             bd=0 if is_active else 2,
    #         )
    #     
    #     # Other label updates
    #     self.attempts_label.config(bg=self.theme.bg_card, fg=self.theme.text_accent)
    #     self.eligible_label.config(bg=self.theme.bg_card, fg=self.theme.text_secondary)
    #     self.metrics_label.config(bg=self.theme.bg_card, fg=self.theme.text_secondary)
    #     self.result_label.config(bg=self.theme.bg_main, fg=self.theme.text_accent)
    
    def open_settings(self):
        SettingsDialog(self.master, self)
    
    def update_debug_display(self):
        """Update the debug display based on debug_mode setting."""
        if self.debug_mode:
            self.result_label.config(
                text=f"Debug: Solution is '{self.target_word.upper()}'",
                fg=self.theme.text_secondary,
            )
        else:
            # Only clear if it's the debug message
            if "Debug:" in self.result_label.cget("text"):
                self.result_label.config(text="")
    
    def change_word_length(self, length):
        self.word_length = length
        self.load_word_list_for_length(length)
        self.reset_game()
        # Update button states
        for l, btn in self.length_buttons.items():
            is_active = l == self.word_length
            is_available = l in self.available_word_lengths
            btn.config(
                bg=self.theme.btn_primary_bg if is_active else self.theme.btn_secondary_bg,
                fg=self.theme.text_inverse if is_active else (self.theme.btn_secondary_fg if is_available else "#666666"),
                relief=FLAT if is_active else RAISED,
                bd=0 if is_active else 2,
                state=NORMAL if is_available else DISABLED,
            )
    
    def change_attempts(self, attempts):
        self.attempts_init = attempts
        self.reset_game()
        for a, btn in self.attempts_buttons.items():
            is_active = a == self.attempts_init
            btn.config(
                bg=self.theme.btn_primary_bg if is_active else self.theme.btn_secondary_bg,
                fg=self.theme.text_inverse if is_active else self.theme.btn_secondary_fg,
                relief=FLAT if is_active else RAISED,
                bd=0 if is_active else 2,
            )
    
    def change_metrics_mode(self, mode):
        # This is kept for compatibility; main metrics update happens elsewhere
        pass
    
    def global_key_handler(self, event):
        """Handle global key presses for grid input."""
        key = event.keysym
        
        # Only process if focus is on main window or its children
        if event.char and event.char.isalpha() and len(event.char) == 1:
            self.word_grid.add_letter(event.char.upper())
        elif key == "BackSpace":
            self.word_grid.delete_letter()
        elif key == "Return":
            self.handle_guess_submit(self.word_grid.get_current_word())
        elif key == "Left":
            r, c = self.word_grid.active_row, self.word_grid.active_col
            if c > 0:
                self.word_grid.set_active_cell(r, c - 1)
        elif key == "Right":
            r, c = self.word_grid.active_row, self.word_grid.active_col
            if c < self.word_grid.cols - 1:
                self.word_grid.set_active_cell(r, c + 1)
    
    def handle_keyboard_click(self, key):
        """Handle keyboard button click."""
        if key == "ENTER":
            self.handle_guess_submit(self.word_grid.get_current_word())
        elif key == "BACKSPACE":
            self.word_grid.delete_letter()
        else:
            self.word_grid.add_letter(key)
    
    def update_keyboard_from_guess(self, guess, results):
        """Update keyboard button colors based on guess results."""
        for letter, result in zip(guess.upper(), results):
            current_state = self.keyboard.letter_states.get(letter)
            if result == "correct":
                self.keyboard.set_letter_state(letter, "correct")
            elif result == "present" and current_state != "correct":
                self.keyboard.set_letter_state(letter, "present")
            elif result == "absent" and current_state not in ("correct", "present"):
                self.keyboard.set_letter_state(letter, "absent")
    
    def handle_guess_submit(self, guess):
        """Handle guess submission from grid."""
        self.guess_word(guess)
    
    def reset_game(self):
        self.attempts = self.attempts_init
        self.target_word, self.target_row = self.choose_word()
        self.eligible_word_list = list(self.word_usage_df["word"].values)
        self.previous_guesses = []
        self.invalid_guesses = set()
        self.guess_metrics = []
        
        self.word_grid.clear_all()
        
        # Clear inline metrics labels
        if hasattr(self.word_grid, '_metrics_labels'):
            for lbl in self.word_grid._metrics_labels.values():
                lbl.destroy()
            self.word_grid._metrics_labels = {}
        
        # Reset keyboard states
        if hasattr(self, 'keyboard'):
            self.keyboard.clear_states()
        
        self.attempts_label.config(
            text=f"{self.attempts} attempts left",
        )
        self.eligible_label.config(
            text=f"{len(self.eligible_word_list)} eligible words",
        )
        self.result_label.config(text="")
        self.metrics_label.config(text="")
        
        # Update debug display if active
        self.update_debug_display()
        
        # Clear word info
        for w in self.word_info_frame.winfo_children():
            w.destroy()
        self.word_info_frame.pack_forget()
    
    def evaluate_guess(self, word, guess):
        """
        Evaluates the player's guess against the target word.
        Returns a list of result strings: 'correct', 'present', 'absent'.
        """
        evaluation = []
        target_counts = {}
        guess_counts = {}
        
        for char in word:
            target_counts[char] = target_counts.get(char, 0) + 1
        for char in guess:
            guess_counts[char] = guess_counts.get(char, 0) + 1
        
        # First pass: greens
        for i, char in enumerate(guess):
            if char == word[i]:
                evaluation.append("correct")
                target_counts[char] -= 1
                guess_counts[char] -= 1
            else:
                evaluation.append(None)
        
        # Second pass: yellows and reds
        for i, char in enumerate(guess):
            if evaluation[i] is None:
                if char in target_counts and target_counts[char] > 0 and guess_counts[char] > 0:
                    evaluation[i] = "present"
                    target_counts[char] -= 1
                    guess_counts[char] -= 1
                else:
                    evaluation[i] = "absent"
        
        return evaluation
    
    def guess_word(self, guess):
        """Process the user's guess."""
        if not guess:
            return
        
        guess = guess.lower()
        
        if len(guess) != self.word_length:
            self.error_label.config(text=f"Enter {self.word_length} letters")
            return
        
        if self.block_old_guesses and guess in self.previous_guesses:
            self.error_label.config(text="Already guessed!")
            return
        
        if not self.is_valid_guess(guess):
            self.error_label.config(text=f"'{guess.upper()}' is not valid!")
            if guess not in self.invalid_guesses:
                self.invalid_guesses.add(guess)
            return
        
        eligible_before_list = self.eligible_word_list.copy()
        self.previous_guesses.append(guess)
        
        # Clear any error message
        self.error_label.config(text="")
        
        colors = self.evaluate_guess(self.target_word, guess)
        self.word_grid.set_results(self.word_grid.active_row, colors)
        self.update_keyboard_from_guess(guess, colors)
        
        # Convert hex colors to result strings for filter_word_list
        hex_eval = []
        for c in colors:
            if c == "correct":
                hex_eval.append("#C6F4D6")
            elif c == "present":
                hex_eval.append("#F7DC6F")
            else:
                hex_eval.append("#FFC5C5")
        
        if guess == self.target_word:
            self.attempts_label.config(
                text=f"Score: {self.attempts_init - self.attempts + 1}",
            )
            self.result_label.config(
                text="You Won!",
                fg=self.theme.accent_success,
            )
            eligible_after_list = [self.target_word]
            self.update_metrics_on_guess(guess, eligible_before_list, eligible_after_list, correct=True)
            self.end_game()
        elif self.attempts > 1:
            self.eligible_word_list = self.filter_word_list(guess, hex_eval)
            eligible_after_list = self.eligible_word_list
            self.attempts -= 1
            self.attempts_label.config(
                text=f"{self.attempts} attempts left",
            )
            self.eligible_label.config(
                text=f"{len(self.eligible_word_list)} eligible words",
            )
            self.update_metrics_on_guess(guess, eligible_before_list, eligible_after_list, correct=False)
            
            self.result_label.config(
                text="",
            )
        else:
            # Last attempt and wrong
            self.eligible_word_list = self.filter_word_list(guess, hex_eval)
            eligible_after_list = self.eligible_word_list
            self.attempts -= 1
            self.update_metrics_on_guess(guess, eligible_before_list, eligible_after_list, correct=False)
            self.lose_game()
    
    def filter_word_list(self, guess, evaluation):
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
    
    def update_metrics_on_guess(self, guess, eligible_before_list, eligible_after_list, correct=False, is_win=False, is_lose=False):
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
        
        # Display inline metrics to the right of the guess row
        if not is_win and not is_lose:
            metrics_str = f"Skill: {skill:.1f} | Luck: {luck:.1f} | {N_before}→{N_after}"
            row = self.word_grid.active_row - 1  # Previous row is where guess was entered
            if row >= 0:
                self.word_grid.display_inline_metrics(metrics_str, row)
        
        self.update_metrics_summary()
    
    def update_metrics_summary(self):
        if not self.guess_metrics:
            self.metrics_label.config(text="")
            return
        total_skill = sum(m["skill"] for m in self.guess_metrics) / len(self.guess_metrics)
        total_luck = sum(m["luck"] for m in self.guess_metrics) / len(self.guess_metrics)
        self.metrics_label.config(text=f"Average: Skill {total_skill:.1f} | Luck {total_luck:.1f}")
    
    def end_game(self):
        self.display_word_info(self.target_row)
        self.word_grid.clear_after_row(self.word_grid.active_row + 1)
    
    def lose_game(self):
        self.attempts_label.config(
            text="0 attempts left",
        )
        self.result_label.config(
            text=f"Correct: {self.target_word.upper()}",
            fg=self.theme.accent_error,
        )
        self.display_word_info(self.target_row)
    
    def display_word_info(self, row):
        self.word_info_frame.pack(fill=X, pady=(16, 0))
        
        # Clear existing
        for w in self.word_info_frame.winfo_children():
            w.destroy()
        
        # Title
        Label(
            self.word_info_frame,
            text=row["word"].upper() if "word" in row else "",
            font=(self.theme.font_family, self.theme.font_size_xlarge, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.text_primary,
        ).pack(pady=(8, 4))
        
        # Audio button (if available)
        audio_path = row.get("audio", "") if row is not None else ""
        if audio_path and not pd.isna(audio_path) and isinstance(audio_path, str):
            if os.path.exists(audio_path):
                Button(
                    self.word_info_frame,
                    text="🔊 Play Audio",
                    font=(self.theme.font_family, self.theme.font_size_base),
                    bg=self.theme.btn_secondary_bg,
                    fg=self.theme.btn_secondary_fg,
                    relief=FLAT,
                    bd=0,
                    padx=16,
                    pady=8,
                    command=lambda: self.play_audio(audio_path),
                ).pack(pady=4)
        
        # Phonetics - COMMENTED OUT as requested
        # try:
        #     phonetics_data = json.loads(row["phonetics"])
        #     for phonetic in phonetics_data:
        #         phonetic_text = phonetic.get("text", "")
        #         Label(
        #             self.word_info_frame,
        #             text=f"/{phonetic_text}/",
        #             font=(self.theme.font_family, self.theme.font_size_small),
        #             bg=self.theme.bg_card,
        #             fg=self.theme.text_secondary,
        #         ).pack()
        # except:
        #     pass
        
        # Definitions - COMMENTED OUT as requested
        # try:
        #     meanings_data = json.loads(row["meanings"])
        #     for meaning in meanings_data:
        #         part_of_speech = meaning.get("partOfSpeech", "")
        #         Label(
        #             self.word_info_frame,
        #             text=f"  {part_of_speech}:",
        #             font=(self.theme.font_family, self.theme.font_size_base, "bold"),
        #             bg=self.theme.bg_card,
        #             fg=self.theme.text_primary,
        #         ).pack(anchor=W, padx=16, pady=(8, 4))
        #         for definition in meaning.get("definitions", []):
        #             def_text = definition.get("definition", "")
        #             Label(
        #                 self.word_info_frame,
        #                 text=f"    • {def_text}",
        #                 font=(self.theme.font_family, self.theme.font_size_base),
        #                 bg=self.theme.bg_card,
        #                 fg=self.theme.text_secondary,
        #                 wraplength=400,
        #                 justify=LEFT,
        #             ).pack(anchor=W, padx=24, pady=2)
        # except:
        #     pass
    
    def play_audio(self, audio_path):
        self.stop_audio()
        try:
            self.audio_player_process = subprocess.Popen(
                ["ffplay", "-nodisp", "-autoexit", os.path.abspath(audio_path)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception as e:
            print(f"Error playing audio: {e}")
    
    def stop_audio(self):
        if self.audio_player_process:
            self.audio_player_process.terminate()
            self.audio_player_process = None


if __name__ == "__main__":
    root = Tk()
    root.title("Lexodle")
    root.geometry("600x900")
    root.minsize(600, 900)
    app = GameWindow(root)
    root.mainloop()
