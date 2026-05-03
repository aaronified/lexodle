"""Settings dialog for Lexodle."""
import tkinter as tk
from tkinter import FLAT, RAISED
from theme import get_theme
from settings import (
    HELPER_MODE_OPTIONS, HELPER_MODE_OFF,
    MIN_WORD_LENGTH, MAX_WORD_LENGTH, MIN_ATTEMPTS, MAX_ATTEMPTS
)
import json


class SettingsDialog:
    """Settings dialog window."""
    
    def __init__(self, parent, game_window):
        self.parent = parent
        self.game_window = game_window
        self.theme = get_theme()
        
        self.top = tk.Toplevel(parent)
        self.top.title("Settings")
        self.top.transient(parent)
        self.top.grab_set()
        self.top.resizable(True, True)
        
        # Center
        x = parent.winfo_x() + 100
        y = parent.winfo_y() + 100
        self.top.geometry(f"350x500+{x}+{y}")
        
        self._create_widgets()
    
    def _create_widgets(self):
        """Create settings widgets."""
        container = tk.Frame(self.top, bg=self.theme.bg_card, padx=24, pady=24)
        container.pack(fill="both", expand=True)
        
        # Title
        tk.Label(
            container,
            text="Settings",
            font=(self.theme.font_family, self.theme.font_size_large, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.text_primary,
            pady=8,
        ).pack()
        
        # New Game button
        tk.Button(
            container,
            text="New Game",
            font=(self.theme.font_family, self.theme.font_size_base),
            width=20,
            pady=8,
            bg=self.theme.btn_secondary_bg,
            fg=self.theme.btn_secondary_fg,
            relief=FLAT,
            bd=0,
            command=self._new_game,
        ).pack(pady=12)
        
        # Word Length dropdown
        tk.Label(
            container,
            text="Word Length:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        self.length_var = tk.StringVar(value=str(self.game_window.word_length))
        self.length_dropdown = tk.OptionMenu(
            container, self.length_var,
            *[str(l) for l in range(MIN_WORD_LENGTH, MAX_WORD_LENGTH + 1)]
        )
        self.length_dropdown.config(
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_input,
            fg=self.theme.text_primary,
            relief=FLAT,
        )
        self.length_dropdown.pack(fill="x", pady=4)
        
        # Attempts dropdown
        tk.Label(
            container,
            text="Attempts:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        self.attempts_var = tk.StringVar(value=str(self.game_window.attempts_init))
        self.attempts_dropdown = tk.OptionMenu(
            container, self.attempts_var,
            *[str(a) for a in range(MIN_ATTEMPTS, MAX_ATTEMPTS + 1)]
        )
        self.attempts_dropdown.config(
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_input,
            fg=self.theme.text_primary,
            relief=FLAT,
        )
        self.attempts_dropdown.pack(fill="x", pady=4)
        
        # Block old guesses - button instead of checkbox
        tk.Label(
            container,
            text="Block Old Guesses:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        self.block_btn = tk.Button(
            container,
            text="ON" if self.game_window.block_old_guesses else "OFF",
            font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            width=8,
            pady=6,
            bg=self.theme.btn_primary_bg if self.game_window.block_old_guesses else self.theme.btn_secondary_bg,
            fg=self.theme.text_inverse,
            relief=FLAT,
            bd=0,
            command=self._toggle_block,
        )
        self.block_btn.pack(pady=4)
        
        # Helper Mode dropdown
        tk.Label(
            container,
            text="Helper Mode:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        current_helper = self.game_window.helper_mode if hasattr(self.game_window, 'helper_mode') else HELPER_MODE_OFF
        self.helper_var = tk.StringVar(value=current_helper)
        self.helper_dropdown = tk.OptionMenu(
            container, self.helper_var,
            *HELPER_MODE_OPTIONS
        )
        self.helper_dropdown.config(
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_input,
            fg=self.theme.text_primary,
            relief=FLAT,
        )
        self.helper_dropdown.pack(fill="x", pady=4)
        
        # Apply and Close buttons
        btn_frame = tk.Frame(container, bg=self.theme.bg_card)
        btn_frame.pack(pady=(24, 0), fill="x")
        
        tk.Button(
            btn_frame,
            text="Apply",
            font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            width=8,
            pady=8,
            bg=self.theme.btn_primary_bg,
            fg=self.theme.btn_primary_fg,
            relief=FLAT,
            bd=0,
            command=self._apply,
        ).pack(side="left", padx=(0, 8))
        
        tk.Button(
            btn_frame,
            text="Cancel",
            font=(self.theme.font_family, self.theme.font_size_base),
            width=8,
            pady=8,
            bg=self.theme.btn_secondary_bg,
            fg=self.theme.btn_secondary_fg,
            relief=FLAT,
            bd=0,
            command=self._cancel,
        ).pack(side="left")
    
    def _new_game(self):
        """Apply settings and start a new game."""
        word_length = int(self.length_var.get())
        attempts = int(self.attempts_var.get())
        helper_mode = self.helper_var.get()
        
        if word_length != self.game_window.word_length:
            self.game_window.change_word_length(word_length)
        
        if attempts != self.game_window.attempts_init:
            self.game_window.change_attempts(attempts)
        
        self.game_window.helper_mode = helper_mode
        self.game_window.block_old_guesses = (self.block_btn.cget("text") == "ON")
        
        # Save config
        config = {
            "default_word_length": word_length,
            "default_attempts": attempts,
            "block_old_guesses": self.game_window.block_old_guesses,
            "available_word_lengths": self.game_window.available_word_lengths,
            "dictionary_file": self.game_window.dictionary_file,
            "helper_mode": helper_mode,
        }
        try:
            with open("./config.json", "w") as f:
                json.dump(config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")
        
        self.game_window.update_helper_display()
        
        self.top.destroy()
        self.game_window.reset_game()
    
    def _toggle_block(self):
        self.game_window.block_old_guesses = not self.game_window.block_old_guesses
        self.block_btn.config(
            text="ON" if self.game_window.block_old_guesses else "OFF",
            bg=self.theme.btn_primary_bg if self.game_window.block_old_guesses else self.theme.btn_secondary_bg,
        )
    
    def _apply(self):
        word_length = int(self.length_var.get())
        attempts = int(self.attempts_var.get())
        helper_mode = self.helper_var.get()
        
        if word_length != self.game_window.word_length:
            self.game_window.change_word_length(word_length)
        
        if attempts != self.game_window.attempts_init:
            self.game_window.change_attempts(attempts)
        
        self.game_window.helper_mode = helper_mode
        self.game_window.block_old_guesses = (self.block_btn.cget("text") == "ON")
        
        # Save config
        config = {
            "default_word_length": word_length,
            "default_attempts": attempts,
            "block_old_guesses": self.game_window.block_old_guesses,
            "available_word_lengths": self.game_window.available_word_lengths,
            "dictionary_file": self.game_window.dictionary_file,
            "helper_mode": helper_mode,
        }
        try:
            with open("./config.json", "w") as f:
                json.dump(config, f, indent=2)
        except Exception as e:
            print(f"Error saving config: {e}")
        
        self.game_window.update_helper_display()
        self.top.destroy()
    
    def _cancel(self):
        self.top.destroy()