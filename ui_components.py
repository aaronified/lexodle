"""
Reusable themed UI components for Lexodle.
"""
import tkinter as tk
from tkinter import font as tkfont
from theme import get_theme


class ThemedButton(tk.Button):
    """A modern themed button with hover effects."""
    
    def __init__(self, parent, text="", command=None, style="primary", **kwargs):
        self.theme = get_theme()
        self.style = style  # "primary", "secondary", "text"
        self._hover = False
        
        kwargs.setdefault("text", text)
        kwargs.setdefault("command", command)
        kwargs.setdefault("font", (self.theme.font_family, self.theme.font_size_base, "bold"))
        kwargs.setdefault("borderwidth", 0)
        kwargs.setdefault("relief", "flat")
        kwargs.setdefault("cursor", "hand2")
        kwargs.setdefault("padx", self.theme.spacing_md)
        kwargs.setdefault("pady", self.theme.spacing_sm)
        
        self._configure_style(style)
        
        super().__init__(parent, **kwargs)
        
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)
    
    def _configure_style(self, style):
        if style == "primary":
            self.config(
                bg=self.theme.btn_primary_bg,
                fg=self.theme.btn_primary_fg,
                activebackground=self.theme.btn_primary_hover,
                activeforeground=self.theme.btn_primary_fg,
            )
        elif style == "secondary":
            self.config(
                bg=self.theme.btn_secondary_bg,
                fg=self.theme.btn_secondary_fg,
                activebackground=self.theme.btn_secondary_hover,
                activeforeground=self.theme.btn_secondary_fg,
            )
        elif style == "text":
            self.config(
                bg="transparent",
                fg=self.theme.text_accent,
                activebackground="transparent",
                activeforeground=self.theme.text_accent,
                font=(self.theme.font_family, self.theme.font_size_base, "normal"),
            )
    
    def _on_enter(self, event):
        self._hover = True
    
    def _on_leave(self, event):
        self._hover = False
    
    def update_theme(self):
        """Update button colors based on current theme."""
        self._configure_style(self.style)


class ThemedLabel(tk.Label):
    """A themed label with proper colors."""
    
    def __init__(self, parent, text="", style="primary", **kwargs):
        self.theme = get_theme()
        self.style = style  # "primary", "secondary", "header", "accent"
        
        kwargs.setdefault("text", text)
        kwargs.setdefault("borderwidth", 0)
        
        self._configure_style()
        
        super().__init__(parent, **kwargs)
    
    def _configure_style(self):
        if self.style == "primary":
            self.config(
                bg=self.theme.bg_card,
                fg=self.theme.text_primary,
                font=(self.theme.font_family, self.theme.font_size_base),
            )
        elif self.style == "secondary":
            self.config(
                bg=self.theme.bg_card,
                fg=self.theme.text_secondary,
                font=(self.theme.font_family, self.theme.font_size_base),
            )
        elif self.style == "header":
            self.config(
                bg=self.theme.bg_header,
                fg=self.theme.text_inverse,
                font=(self.theme.font_family, self.theme.font_size_large, "bold"),
            )
        elif self.style == "accent":
            self.config(
                bg=self.theme.bg_card,
                fg=self.theme.text_accent,
                font=(self.theme.font_family, self.theme.font_size_base, "bold"),
            )
        elif self.style == "title":
            self.config(
                bg=self.theme.bg_header,
                fg=self.theme.text_inverse,
                font=(self.theme.font_family, self.theme.font_size_xlarge, "bold"),
            )
    
    def update_theme(self):
        """Update label colors based on current theme."""
        self._configure_style()


class ThemedFrame(tk.Frame):
    """A themed frame/card with shadow effect."""
    
    def __init__(self, parent, style="card", **kwargs):
        self.theme = get_theme()
        self.style = style  # "card", "header", "input", "plain"
        
        self._configure_style()
        
        kwargs.setdefault("borderwidth", 0)
        kwargs.setdefault("highlightthickness", 0)
        
        super().__init__(parent, **kwargs)
    
    def _configure_style(self):
        if self.style == "card":
            self.config(
                bg=self.theme.bg_card,
            )
        elif self.style == "header":
            self.config(
                bg=self.theme.bg_header,
            )
        elif self.style == "input":
            self.config(
                bg=self.theme.bg_input,
            )
        elif self.style == "plain":
            self.config(
                bg=self.theme.bg_main,
            )
    
    def update_theme(self):
        """Update frame colors based on current theme."""
        self._configure_style()


class ProgressModal:
    """A modal dialog showing progress."""
    
    def __init__(self, parent, title="Processing", message="Please wait..."):
        self.parent = parent
        self.theme = get_theme()
        
        # Create overlay
        self.overlay = tk.Toplevel(parent)
        self.overlay.title(title)
        self.overlay.transient(parent)
        self.overlay.grab_set()
        self.overlay.resizable(False, False)
        
        self.overlay.configure(bg=self.theme.bg_card)
        
        # Center on parent
        parent_x = parent.winfo_x()
        parent_y = parent.winfo_y()
        parent_w = parent.winfo_width()
        parent_h = parent.winfo_height()
        modal_w = 400
        modal_h = 180
        x = parent_x + (parent_w - modal_w) // 2
        y = parent_y + (parent_h - modal_h) // 2
        self.overlay.geometry(f"{modal_w}x{modal_h}+{x}+{y}")
        
        # Content
        container = tk.Frame(self.overlay, bg=self.theme.bg_card, padx=self.theme.spacing_lg, pady=self.theme.spacing_lg)
        container.pack(fill="both", expand=True)
        
        tk.Label(
            container,
            text=title,
            font=(self.theme.font_family, self.theme.font_size_large, "bold"),
            bg=self.theme.bg_card,
            fg=self.theme.text_primary,
        ).pack(pady=(0, self.theme.spacing_sm))
        
        self.message_label = tk.Label(
            container,
            text=message,
            font=(self.theme.font_family, self.theme.font_size_base),
            bg=self.theme.bg_card,
            fg=self.theme.text_secondary,
        )
        self.message_label.pack(pady=(0, self.theme.spacing_md))
        
        # Progress bar
        self.progress_var = tk.DoubleVar(value=0)
        self.progress_bar = tk.ttk.Progressbar(
            container,
            variable=self.progress_var,
            maximum=100,
            mode="determinate",
        )
        self.progress_bar.pack(fill="x", pady=(0, self.theme.spacing_sm))
        
        # Style the progress bar
        style = tk.ttk.Style()
        if self.theme.is_dark:
            style.theme_use("clam")
            style.configure("TProgressbar",
                background=self.theme.accent_success,
                troughcolor=self.theme.bg_input,
                bordercolor=self.theme.border_color,
            )
        else:
            style.theme_use("clam")
            style.configure("TProgressbar",
                background=self.theme.accent_success,
                troughcolor=self.theme.bg_input,
                bordercolor=self.theme.border_color,
            )
    
    def set_progress(self, value):
        """Set progress percentage (0-100)."""
        self.progress_var.set(value)
        self.overlay.update_idletasks()
    
    def set_message(self, message):
        """Update the message text."""
        self.message_label.config(text=message)
        self.overlay.update_idletasks()
    
    def close(self):
        """Close the modal."""
        self.overlay.grab_release()
        self.overlay.destroy()
