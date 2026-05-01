"""
Theme configuration for Lexodle - Light/Dark mode support.
"""

class Theme:
    """Manages theme state and color palettes."""
    
    def __init__(self, mode="light"):
        self.mode = mode  # "light" or "dark"
    
    def toggle(self):
        """Toggle between light and dark mode."""
        self.mode = "dark" if self.mode == "light" else "light"
    
    @property
    def is_dark(self):
        return self.mode == "dark"
    
    # Background colors
    @property
    def bg_main(self):
        return "#1a1a2e" if self.is_dark else "#f5f7fa"
    
    @property
    def bg_card(self):
        return "#16213e" if self.is_dark else "#ffffff"
    
    @property
    def bg_input(self):
        return "#0f3460" if self.is_dark else "#f0f4f8"
    
    @property
    def bg_active(self):
        return "#e94560" if self.is_dark else "#e94560"
    
    @property
    def bg_header(self):
        return "#0f3460" if self.is_dark else "#4a6fa5"
    
    # Text colors
    @property
    def text_primary(self):
        return "#e6e6e6" if self.is_dark else "#2c3e50"
    
    @property
    def text_secondary(self):
        return "#a0a0b0" if self.is_dark else "#5a6c7e"
    
    @property
    def text_inverse(self):
        return "#ffffff" if self.is_dark else "#ffffff"
    
    @property
    def text_accent(self):
        return "#e94560" if self.is_dark else "#e94560"
    
    # Border colors
    @property
    def border_color(self):
        return "#2a2a4e" if self.is_dark else "#d1d9e6"
    
    @property
    def border_focus(self):
        return "#e94560" if self.is_dark else "#4a6fa5"
    
    # Cell colors (Wordle-style)
    @property
    def cell_correct(self):
        return "#2e8b57" if self.is_dark else "#2e8b57"
    
    @property
    def cell_present(self):
        return "#b8860b" if self.is_dark else "#b8860b"
    
    @property
    def cell_absent(self):
        return "#4a4a5a" if self.is_dark else "#8b8b9a"
    
    @property
    def cell_empty(self):
        return "transparent"
    
    @property
    def cell_empty_border(self):
        return "#2a2a4e" if self.is_dark else "#d1d9e6"
    
    @property
    def cell_active_border(self):
        return "#e94560"
    
    # Button colors
    @property
    def btn_primary_bg(self):
        return "#e94560" if self.is_dark else "#4a6fa5"
    
    @property
    def btn_primary_fg(self):
        return "#ffffff"
    
    @property
    def btn_primary_hover(self):
        return "#c73650" if self.is_dark else "#3a5a8a"
    
    @property
    def btn_secondary_bg(self):
        return "#2a2a4e" if self.is_dark else "#e8ecf0"
    
    @property
    def btn_secondary_fg(self):
        return "#e6e6e6" if self.is_dark else "#2c3e50"
    
    @property
    def btn_secondary_hover(self):
        return "#3a3a5e" if self.is_dark else "#d1d9e6"
    
    # Accent colors
    @property
    def accent_success(self):
        return "#2e8b57"
    
    @property
    def accent_warning(self):
        return "#b8860b"
    
    @property
    def accent_error(self):
        return "#e94560"
    
    # Shadow/effects
    @property
    def shadow_card(self):
        if self.is_dark:
            return "0 4px 20px rgba(0,0,0,0.4)"
        return "0 2px 12px rgba(0,0,0,0.08)"
    
    @property
    def shadow_header(self):
        if self.is_dark:
            return "0 2px 10px rgba(0,0,0,0.3)"
        return "0 2px 8px rgba(0,0,0,0.1)"
    
    # Font
    @property
    def font_family(self):
        return "Segoe UI, Roboto, Helvetica, Arial, sans-serif"
    
    @property
    def font_size_base(self):
        return 13
    
    @property
    def font_size_large(self):
        return 18
    
    @property
    def font_size_xlarge(self):
        return 24
    
    @property
    def font_size_small(self):
        return 11
    
    # Spacing
    @property
    def spacing_xs(self):
        return 4
    
    @property
    def spacing_sm(self):
        return 8
    
    @property
    def spacing_md(self):
        return 16
    
    @property
    def spacing_lg(self):
        return 24
    
    @property
    def spacing_xl(self):
        return 32
    
    # Grid cell
    @property
    def cell_size(self):
        return 52
    
    @property
    def cell_gap(self):
        return 6
    
    @property
    def cell_font_size(self):
        return 26
    
    @property
    def cell_border_width(self):
        return 2
    
    @property
    def cell_border_width_active(self):
        return 3


_theme = Theme("light")

def get_theme():
    """Get the global theme instance."""
    return _theme

def set_theme_mode(mode):
    """Set the global theme mode ('light' or 'dark')."""
    _theme.mode = mode
