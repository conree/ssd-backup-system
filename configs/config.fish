# Fish Shell Configuration
# Environment variables
set -gx EDITOR nvim
fish_add_path ~/.local/bin
fish_add_path ~/.cargo/bin

# Enhanced aliases
alias ll="eza -la --git"
alias la="eza -la --git" 
alias ls="eza"
alias cat="bat"
alias grep="rg"
alias find="fd"
alias vim="nvim"
alias top="btop"
alias du="dust"
alias df="duf"

# Git aliases
alias gs="git status"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git log --oneline"
alias gd="git diff"

# System functions
function backup_configs
    set backup_dir ~/config_backup_(date +%Y%m%d_%H%M%S)
    mkdir -p $backup_dir
    cp -r ~/.config $backup_dir/
    cp -r ~/scripts $backup_dir/
    echo "Configs backed up to $backup_dir"
end

function run_backup
    sudo ~/scripts/ssd_backup.fish
end

function update_system
    sudo pacman -Syu
    yay -Syu --noconfirm
end

function help_restore
    echo "Post-restoration commands:"
    echo "  backup_configs - Backup current configs"
    echo "  update_system - Update all packages"
    echo "  run_backup - Start SSD backup"
    echo "  ll - Enhanced directory listing"
end

# Set monitors to 100% brightness (only once per session)
if not set -q MONITORS_INITIALIZED
    timeout 3s ddcutil setvcp 10 100 &>/dev/null &
    set -gx MONITORS_INITIALIZED 1
end

# Custom greeting with fastfetch
function fish_greeting
    fastfetch
    echo ""
    echo "Welcome back! Your restored system is running perfectly."
    echo "Type 'help_restore' for restoration commands."
end
