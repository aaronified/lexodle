"""Settings dialog for Lexodle."""
import tkinter as tk
from tkinter import IntVar, BooleanVar, FLAT, RAISED
from theme import get_theme


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
        self.top.geometry(f"350x400+{x}+{y}")
        
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
        
        # Word Length selector
        tk.Label(
            container,
            text="Word Length:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        self.length_var = IntVar(value=self.game_window.word_length)
        length_frame = tk.Frame(container, bg=self.theme.bg_card)
        length_frame.pack(fill="x", pady=4)
        
        for l in [5, 6, 7, 8]:
            btn = tk.Button(
                length_frame,
                text=str(l),
                font=(self.theme.font_family, self.theme.font_size_base, "bold"),
                width=5,
                pady=6,
                bg=self.theme.btn_primary_bg if l == self.game_window.word_length else self.theme.btn_secondary_bg,
                fg=self.theme.text_inverse if l == self.game_window.word_length else self.theme.btn_secondary_fg,
                relief=FLAT if l == self.game_window.word_length else RAISED,
                bd=0 if l == self.game_window.word_length else 2,
                command=lambda ll=l: self._set_word_length(ll),
            )
            btn.pack(side="left", padx=2)
            self.length_var.set(l)
        
        # Attempts selector
        tk.Label(
            container,
            text="Attempts:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        self.attempts_var = IntVar(value=self.game_window.attempts_init)
        attempts_frame = tk.Frame(container, bg=self.theme.bg_card)
        attempts_frame.pack(fill="x", pady=4)
        
        for a in [4, 5, 6, 7, 8]:
            btn = tk.Button(
                attempts_frame,
                text=str(a),
                font=(self.theme.font_family, self.theme.font_size_base, "bold"),
                width=5,
                pady=6,
                bg=self.theme.btn_primary_bg if a == self.game_window.attempts_init else self.theme.btn_secondary_bg,
                fg=self.theme.text_inverse if a == self.game_window.attempts_init else self.theme.btn_secondary_fg,
                relief=FLAT if a == self.game_window.attempts_init else RAISED,
                bd=0 if a == self.game_window.attempts_init else 2,
                command=lambda aa=a: self._set_attempts(aa),
            )
            btn.pack(side="left", padx=2)
        
        # Block old guesses - button instead of checkbox
        tk.Label(
            container,
            text="Block Old Guesses:",
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        ).pack(anchor="w", pady=(16, 4))
        
        self.block_var = BooleanVar(value=self.game_window.block_old_guesses)
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
        
        # Debug mode
        debug_var = BooleanVar(value=self.game_window.debug_mode)
        cb_debug = tk.Checkbutton(
            container,
            text="Debug Mode (show solution)",
            variable=debug_var,
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
            command=lambda: [setattr(self.game_window, 'debug_mode', debug_var.get()), self.game_window.update_debug_display()],
        )
        cb_debug.pack(pady=(16, 0))
    
    def _new_game(self):
        self.top.destroy()
        self.game_window.reset_game()
    
    def _set_word_length(self, length):
        self.game_window.change_word_length(length)
        self.top.destroy()
    
    def _set_attempts(self, attempts):
        self.game_window.change_attempts(attempts)
        self.top.destroy()
    
    def _toggle_block(self):
        self.game_window.block_old_guesses = not self.game_window.block_old_guesses
        self.block_btn.config(
            text="ON" if self.game_window.block_old_guesses else "OFF",
            bg=self.theme.btn_primary_bg if self.game_window.block_old_guesses else self.theme.btn_secondary_bg,
        )