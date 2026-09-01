# Ryoku palette for fish and fzf. Rendered by the theme daemon; do not edit.
#
# Dropped straight into conf.d, which fish sources on its own, so nothing in the
# shipped config has to include it. Your ~/.config/fish/user.fish loads last and
# still wins.

# Syntax highlighting.
set -g fish_color_normal cdd6f4
set -g fish_color_command b4befe
set -g fish_color_keyword 94e2d5
set -g fish_color_quote f2cdcd
set -g fish_color_redirection bac2de
set -g fish_color_end 94e2d5
set -g fish_color_error f38ba8
set -g fish_color_param cdd6f4
set -g fish_color_comment bac2de
set -g fish_color_selection --background=313244
set -g fish_color_operator 94e2d5
set -g fish_color_escape f2cdcd
set -g fish_color_autosuggestion bac2de
set -g fish_color_cancel f38ba8
set -g fish_color_search_match --background=313244
set -g fish_color_valid_path --underline

# Completion pager.
set -g fish_pager_color_progress bac2de
set -g fish_pager_color_prefix b4befe
set -g fish_pager_color_completion cdd6f4
set -g fish_pager_color_description bac2de
set -g fish_pager_color_selected_background --background=313244

# fzf takes the same palette, so Ctrl-R and Ctrl-T match the terminal they open
# in. Appended to whatever options are already set rather than replacing them.
set -gx FZF_DEFAULT_OPTS "$FZF_DEFAULT_OPTS \
--color=fg:#cdd6f4,bg:-1,hl:#b4befe \
--color=fg+:#cdd6f4,bg+:#313244,hl+:#b4befe \
--color=info:#f2cdcd,prompt:#b4befe,pointer:#94e2d5 \
--color=marker:#94e2d5,spinner:#f2cdcd,header:#bac2de \
--color=border:#6c7086"
