if status is-interactive
    fish_add_path --path $HOME/.local/bin

    if command -q brew
        set -l brew_prefix (brew --prefix)
        fish_add_path --path $brew_prefix/bin $brew_prefix/sbin
    end

    if test -d $HOME/.local/share/uv/tools/bin
        fish_add_path --path $HOME/.local/share/uv/tools/bin
    end

    if command -q mise
        mise activate fish | source
    end

    if command -q zoxide
        zoxide init fish | source
    end

    if command -q starship
        starship init fish | source
    end
end
