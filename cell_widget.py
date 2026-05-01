"""
Grid-based word input system for Lexodle.
Replaces the single Entry widget with a clickable cell grid.
"""
import tkinter as tk
from tkinter import FLAT
from theme import get_theme


class Cell:
    """A single cell in the word grid. Clickable, shows a letter."""
    
    def __init__(self, parent, row, col, size=52, on_click=None, on_change=None):
        self.row = row
        self.col = col
        self.size = size
        self.on_click = on_click
        self.on_change = on_change
        self.theme = get_theme()
        
        self.letter = ""
        self.state = "empty"  # "empty", "filled", "correct", "present", "absent", "active"
        
        self._create_widgets(parent)
    
    def _create_widgets(self, parent):
        """Create the cell's Tkinter widgets."""
        self.frame = tk.Frame(
            parent,
            width=self.size,
            height=self.size,
            bg=self.theme.bg_input,
            highlightthickness=self.theme.cell_border_width,
            highlightbackground=self.theme.cell_empty_border,
        )
        self.frame.grid_propagate(False)
        
        self.label = tk.Label(
            self.frame,
            text="",
            font=("Segoe UI", self.theme.cell_font_size, "bold"),
            bg=self.theme.bg_input,
            fg=self.theme.text_primary,
        )
        self.label.place(relx=0.5, rely=0.5, anchor="center")
        
        # Bind click
        self.frame.bind("<Button-1>", self._on_click)
        self.label.bind("<Button-1>", self._on_click)
    
    def _on_click(self, event):
        """Handle click - set as active cell."""
        if self.on_click:
            self.on_click(self.row, self.col)
    
    def set_active(self, active=True):
        """Set/unset active state (highlight border)."""
        if active:
            self.frame.config(
                highlightthickness=self.theme.cell_border_width_active,
                highlightbackground=self.theme.cell_active_border,
            )
        else:
            self._update_border()
    
    def set_letter(self, letter):
        """Set the letter in this cell."""
        self.letter = letter.upper() if letter else ""
        self.label.config(text=self.letter)
        
        if self.letter:
            self.state = "filled"
            self._update_border()
        else:
            self.state = "empty"
            self._update_border()
        
        if self.on_change:
            self.on_change(self.row, self.col, self.letter)
    
    def set_result(self, result):
        """Set the evaluation result for this cell.
        
        Args:
            result: "correct" (green), "present" (yellow), "absent" (red), or None to clear.
        """
        self.state = result if result else "filled" if self.letter else "empty"
        self._update_border()
        self._update_bg()
    
    def clear_result(self):
        """Clear evaluation result, revert to neutral."""
        if self.state in ("correct", "present", "absent"):
            self.state = "filled" if self.letter else "empty"
            self._update_border()
            self._update_bg()
    
    def _update_border(self):
        """Update border color based on state."""
        if self.state == "active":
            color = self.theme.cell_active_border
            width = self.theme.cell_border_width_active
        elif self.state == "filled":
            try:
                bg = self.frame.cget("bg")
                has_result_bg = bg in (self.theme.cell_correct, self.theme.cell_present, self.theme.cell_absent)
            except:
                has_result_bg = False
            if has_result_bg:
                color = self.theme.cell_empty_border
                width = self.theme.cell_border_width
            else:
                color = self.theme.border_focus
                width = self.theme.cell_border_width_active
        elif self.state in ("correct", "present", "absent"):
            color = self.theme.cell_empty_border
            width = self.theme.cell_border_width
        else:  # empty
            color = self.theme.cell_empty_border
            width = self.theme.cell_border_width
        
        self.frame.config(
            highlightthickness=width,
            highlightbackground=color,
        )
    
    def _update_bg(self):
        """Update background color based on state."""
        if self.state == "correct":
            bg = self.theme.cell_correct
            fg = self.theme.text_inverse
        elif self.state == "present":
            bg = self.theme.cell_present
            fg = self.theme.text_inverse
        elif self.state == "absent":
            bg = self.theme.cell_absent
            fg = self.theme.text_inverse
        elif self.state == "filled" or self.state == "active":
            bg = self.theme.bg_input
            fg = self.theme.text_primary
        else:  # empty
            bg = self.theme.bg_input
            fg = self.theme.text_primary
        
        self.frame.config(bg=bg)
        self.label.config(bg=bg, fg=fg)
    
    def reset(self):
        """Reset cell to initial empty state."""
        self.letter = ""
        self.state = "empty"
        self.label.config(text="")
        self.frame.config(
            bg=self.theme.bg_input,
            highlightthickness=self.theme.cell_border_width,
            highlightbackground=self.theme.cell_empty_border,
        )
        self.label.config(bg=self.theme.bg_input, fg=self.theme.text_primary)
    
    def set_theme(self):
        """Update colors for theme change."""
        self.theme = get_theme()
        if self.state == "empty":
            self.frame.config(bg=self.theme.bg_input)
            self.label.config(bg=self.theme.bg_input, fg=self.theme.text_primary)
        elif self.state == "filled":
            self._update_bg()
        elif self.state in ("correct", "present", "absent"):
            self._update_bg()
        self._update_border()
    
    def pack(self, **kwargs):
        self.frame.pack(**kwargs)
    
    def grid(self, **kwargs):
        self.frame.grid(**kwargs)
    
    def place(self, **kwargs):
        self.frame.place(**kwargs)


class WordGrid:
    """A 6x5 grid of cells for word input."""
    
    def __init__(self, parent, rows=6, cols=5, on_submit=None):
        self.rows = rows
        self.cols = cols
        self.on_submit = on_submit
        self.theme = get_theme()
        
        self.active_row = 0
        self.active_col = 0
        self.cells = [[None for _ in range(cols)] for _ in range(rows)]
        
        self._create_widgets(parent)
    
    def _create_widgets(self, parent):
        """Create the grid of cells."""
        self.container = tk.Frame(parent, bg=self.theme.bg_input)
        
        for r in range(self.rows):
            for c in range(self.cols):
                cell = Cell(
                    self.container,
                    row=r,
                    col=c,
                    size=self.theme.cell_size,
                    on_click=self._cell_clicked,
                    on_change=self._cell_changed,
                )
                cell.grid(row=r, column=c, padx=self.theme.cell_gap // 2, pady=self.theme.cell_gap // 2)
                self.cells[r][c] = cell
        
        # Set initial active cell
        if self.rows > 0 and self.cols > 0:
            self.cells[0][0].set_active(True)
    
    def _cell_clicked(self, row, col):
        """Handle cell click - set as active."""
        self.set_active_cell(row, col)
    
    def _cell_changed(self, row, col, letter):
        """Handle cell letter change - auto-advance."""
        if letter and col < self.cols - 1:
            next_empty = None
            for nc in range(col + 1, self.cols):
                if not self.cells[row][nc].letter:
                    next_empty = nc
                    break
            if next_empty is not None:
                self.set_active_cell(row, next_empty)
    
    def set_active_cell(self, row, col):
        """Set the active cell."""
        if 0 <= row < self.rows and 0 <= col < self.cols:
            # Don't allow navigating to or editing rows that have been evaluated
            if any(self.cells[row][c].state in ("correct", "present", "absent") for c in range(self.cols)):
                return
            # Deactivate current
            self.cells[self.active_row][self.active_col].set_active(False)
            # Activate new
            self.active_row = row
            self.active_col = col
            self.cells[row][col].set_active(True)
    
    def get_current_word(self):
        """Get the word in the current active row."""
        row = self.cells[self.active_row]
        letters = [cell.letter for cell in row]
        return "".join(letters)
    
    def get_row_word(self, row_idx):
        """Get the word from a specific row."""
        if 0 <= row_idx < self.rows:
            letters = [cell.letter for cell in self.cells[row_idx]]
            return "".join(letters)
        return ""
    
    def add_letter(self, letter):
        """Add a letter to the active cell and move right."""
        row = self.active_row
        col = self.active_col
        
        # Don't allow editing evaluated rows
        if any(self.cells[row][c].state in ("correct", "present", "absent") for c in range(self.cols)):
            return
        
        # Fill current cell
        self.cells[row][col].set_letter(letter)
        
        # Move to next empty cell in row
        next_col = None
        for c in range(col + 1, self.cols):
            if not self.cells[row][c].letter:
                next_col = c
                break
        
        if next_col is not None:
            self.set_active_cell(row, next_col)
    
    def delete_letter(self):
        """Delete letter from active cell and move left."""
        row = self.active_row
        col = self.active_col
        
        # Don't allow editing evaluated rows
        if any(self.cells[row][c].state in ("correct", "present", "absent") for c in range(self.cols)):
            return
        
        if self.cells[row][col].letter:
            # Clear current cell
            self.cells[row][col].set_letter("")
        elif col > 0:
            # Move left and clear
            prev_col = col - 1
            self.cells[row][prev_col].set_letter("")
            self.set_active_cell(row, prev_col)
    
    def submit_guess(self):
        """Submit the current row as a guess."""
        word = self.get_current_word()
        if len(word) == self.cols and self.on_submit:
            self.on_submit(word)
    
    def set_results(self, row_idx, results):
        """Set evaluation results for a row.
        
        Args:
            row_idx: Row index to update
            results: List of result strings ("correct", "present", "absent")
        """
        if 0 <= row_idx < self.rows:
            for col, result in enumerate(results):
                self.cells[row_idx][col].set_result(result)
            # Move to next row
            if row_idx + 1 < self.rows:
                self.set_active_cell(row_idx + 1, 0)
    
    def display_inline_metrics(self, metrics_str, row_idx):
        """Display metrics string to the right of the row.
        
        Args:
            metrics_str: Formatted metrics string (e.g., "Skill: 45.2 | Luck: 62.1 | Words: 123→45")
            row_idx: Row index to display metrics for
        """
        from theme import get_theme
        theme = get_theme()
        
        # Create or update metrics label for this row
        if not hasattr(self, '_metrics_labels'):
            self._metrics_labels = {}
        
        # Remove old metrics label if exists
        if row_idx in self._metrics_labels:
            self._metrics_labels[row_idx].destroy()
        
        # Create new metrics label
        label = tk.Label(
            self.container,
            text=metrics_str,
            font=(theme.font_family, theme.font_size_small),
            bg=theme.bg_card,
            fg=theme.text_secondary,
        )
        label.grid(row=row_idx, column=self.cols, padx=(self.theme.cell_gap, 0))
        self._metrics_labels[row_idx] = label
    
    def clear_after_row(self, row_idx):
        """Clear all rows after and including the given row."""
        for r in range(row_idx, self.rows):
            self.clear_row(r)
        # Reset active to first empty row
        first_empty = row_idx
        if first_empty >= self.rows:
            first_empty = self.rows - 1
        self.set_active_cell(first_empty, 0)
    
    def clear_row(self, row_idx):
        """Clear all cells in a row."""
        if 0 <= row_idx < self.rows:
            for cell in self.cells[row_idx]:
                cell.reset()
    
    def clear_all(self):
        """Clear the entire grid."""
        for r in range(self.rows):
            self.clear_row(r)
        self.set_active_cell(0, 0)
    
    def reset_results(self, row_idx):
        """Clear evaluation results from a row but keep letters."""
        if 0 <= row_idx < self.rows:
            for cell in self.cells[row_idx]:
                cell.clear_result()
    
    def set_theme(self):
        """Update all cells for theme change."""
        self.theme = get_theme()
        self.container.config(bg=self.theme.bg_input)
        for row in self.cells:
            for cell in row:
                cell.set_theme()
    
    def pack(self, **kwargs):
        self.container.pack(**kwargs)
    
    def grid(self, **kwargs):
        self.container.grid(**kwargs)
    
    def place(self, **kwargs):
        self.container.place(**kwargs)
    
    def focus(self):
        """Focus the grid (for keyboard input)."""
        self.container.focus_set()


class Keyboard:
    """QWERTY keyboard widget for letter input."""
    
    def __init__(self, parent, on_key_click=None, letter_states=None):
        self.parent = parent
        self.on_key_click = on_key_click
        self.theme = get_theme()
        self.letter_states = letter_states or {}
        
        self._create_widgets(parent)
    
    def _create_widgets(self, parent):
        """Create the keyboard layout."""
        self.container = tk.Frame(parent, bg=self.theme.bg_card)
        
        rows = ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
        self.key_buttons = {}
        
        for row_letters in rows:
            row_frame = tk.Frame(self.container, bg=self.theme.bg_card)
            row_frame.pack(pady=2)
            
            for letter in row_letters:
                btn = tk.Button(
                    row_frame, text=letter,
                    font=(self.theme.font_family, 11, "bold"),
                    width=4, padx=4, pady=8,
                    bg=self.theme.btn_secondary_bg,
                    fg=self.theme.btn_secondary_fg,
                    relief=FLAT, bd=0,
                    command=lambda l=letter: self._key_click(l),
                )
                btn.grid(row=0, column=len(self.key_buttons) % 10, padx=2)
                self.key_buttons[letter] = btn
        
        special_frame = tk.Frame(self.container, bg=self.theme.bg_card)
        special_frame.pack(pady=2)
        
        self.enter_btn = tk.Button(
            special_frame, text="ENTER",
            font=(self.theme.font_family, 10, "bold"),
            width=8, padx=4, pady=6,
            bg=self.theme.btn_secondary_bg,
            fg=self.theme.btn_secondary_fg,
            relief=FLAT, bd=0,
            command=lambda: self._key_click("ENTER"),
        )
        self.enter_btn.grid(row=0, column=0, padx=2)
        
        self.backspace_btn = tk.Button(
            special_frame, text="⌫",
            font=(self.theme.font_family, 11, "bold"),
            width=4, padx=4, pady=6,
            bg=self.theme.btn_secondary_bg,
            fg=self.theme.btn_secondary_fg,
            relief=FLAT, bd=0,
            command=lambda: self._key_click("BACKSPACE"),
        )
        self.backspace_btn.grid(row=0, column=1, padx=2)
    
    def _key_click(self, key):
        if self.on_key_click:
            self.on_key_click(key)
    
    def set_letter_state(self, letter, state):
        letter = letter.upper()
        self.letter_states[letter] = state
        if letter not in self.key_buttons:
            return
        if state == "correct":
            bg, fg = self.theme.cell_correct, self.theme.text_inverse
        elif state == "present":
            bg, fg = self.theme.cell_present, self.theme.text_inverse
        elif state == "absent":
            bg, fg = self.theme.cell_absent, self.theme.text_inverse
        else:
            bg, fg = self.theme.btn_secondary_bg, self.theme.btn_secondary_fg
        self.key_buttons[letter].config(bg=bg, fg=fg)
    
    def clear_states(self):
        self.letter_states = {}
        for btn in self.key_buttons.values():
            btn.config(bg=self.theme.btn_secondary_bg, fg=self.theme.btn_secondary_fg)
    
    def pack(self, **kwargs):
        self.container.pack(**kwargs)
    
    def grid(self, **kwargs):
        self.container.grid(**kwargs)