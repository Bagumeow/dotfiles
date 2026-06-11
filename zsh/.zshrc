# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time Oh My Zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-syntax-highlighting zsh-autosuggestions zsh-completions)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch $(uname -m)"

# Set personal aliases, overriding those provided by Oh My Zsh libs,
# plugins, and themes. Aliases can be placed here, though Oh My Zsh
# users are encouraged to define aliases within a top-level file in
# the $ZSH_CUSTOM folder, with .zsh extension. Examples:
# - $ZSH_CUSTOM/aliases.zsh
# - $ZSH_CUSTOM/macos.zsh
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# ── Merged from ~/.zshrc.pre-oh-my-zsh ──────────────────────────────

alias python="python3.12"
alias pip="pip3.12"

#git
alias pull="git pull"
alias push="git push"
alias commit="git commit -m"
alias add="git add ."
alias status="git status"
alias checkout="git checkout"

#kubectl
alias k="kubectl"
alias kube="kubectl"
alias kns="kubens"
alias describe="kubectl describe"
alias po="kubectl get pods"
alias svc="kubectl get services"
alias deploy="kubectl get deployments"
alias ingress="kubectl get ingress"
alias configmap="kubectl get configmaps"
alias secret="kubectl get secrets"
alias pvc="kubectl get pvc"
alias use-context="kubectl config use-context"

alias claudesudo="claude --dangerously-skip-permissions"

# Disable default virtualenv prompt modification
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Function to get current Git branch (only if in git repo)
git_branch() {
    local branch=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/')
    if [[ -n "$branch" ]]; then
        echo "($branch)"
    fi
}

# Function to get current k8s namespace
k8s_namespace() {
    kubens -c 2>/dev/null || echo "default"
}

# Function to show directory with hyphen only if not home
dir_with_separator() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo ""
    else
        echo "%F{white}-%f%F{blue}%1~%f"
    fi
}

# Function to determine context prefix (venv or namespace)
context_prefix() {
    if [[ -n "$VIRTUAL_ENV" ]]; then
        # Extract virtualenv name from path (basename)
        local venv_name=$(basename "$VIRTUAL_ENV")
        echo "%F{cyan}($venv_name)%F{white}-%f"
    else
        # Use namespace without parentheses (they'll be added in PROMPT)
        echo "%F{cyan}"
    fi
}

# Function to determine context suffix (namespace or nothing)
context_suffix() {
    echo "%F{yellow}($(k8s_namespace))%f"
}

# Custom prompt with colors following format: (.venv)user-workdir(branch) or user(namespace)-workdir(branch)
# Overrides the oh-my-zsh theme prompt (must stay below `source $ZSH/oh-my-zsh.sh`)
autoload -U colors && colors
setopt PROMPT_SUBST

PROMPT='$(context_prefix)%F{green}%n%f$(context_suffix)$(dir_with_separator)%F{magenta}$(git_branch)%f$ '


eval $(thefuck --alias)
export PATH=$PATH:$HOME/Library/Android/sdk/platform-tools

# Added by Antigravity
export PATH="/Users/nghiale/.antigravity/antigravity/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export WORKLOGS_GITHUB_TOKEN="ghp_" # Replace with your actual token

export JAVA_HOME=/Users/nghiale/Library/Java/JavaVirtualMachines/temurin-17.0.18/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
M2_HOME='/Users/nghiale/.m2/apache-maven-3.9.14'
PATH="$M2_HOME/bin:$PATH"
export PATH
alias unquar='xattr -dr com.apple.quarantine'
