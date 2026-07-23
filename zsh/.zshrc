# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-syntax-highlighting zsh-autosuggestions zsh-completions)
source $ZSH/oh-my-zsh.sh

alias python="python3.12"
alias pip="pip3.12"

#git
alias pull="git pull"
alias push="git push"
alias commit="git commit -m"
alias add="git add ."
alias status="git status"
alias checkout="git checkout"
#base64
encode64() { echo -n "$1" | base64 }
decode64() { echo "$1" | base64 -d }
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
claude-sub() { CLAUDE_CONFIG_DIR=~/.claude-sub claude "$@"; }

alias ala='alacritty msg create-window --working-directory "$PWD" 2>/dev/null || open -na Alacritty --args --working-directory "$PWD"'
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

# Lấy GCP project từ context k8s hiện tại — cluster GKE có dạng
# gke_<project>_<region>_<cluster>; nếu không phải GKE thì hiện tên context
k8s_project() {
    local cluster=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}' 2>/dev/null)
    if [[ "$cluster" == gke_* ]]; then
        local rest="${cluster#gke_}"
        echo "${rest%%_*}"
    else
        kubectl config current-context 2>/dev/null || echo "none"
    fi
}

# Function to show directory with hyphen only if not home
dir_with_separator() {
    if [[ "$PWD" == "$HOME" ]]; then
        echo ""
    else
        echo "%F{white}-%f%F{81}%1~%f"
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

# Function to determine context suffix (project:namespace) — project vàng gold (220), namespace hồng raspberry (204)
context_suffix() {
    echo "%F{220}($(k8s_project):%F{204}$(k8s_namespace)%F{220})%f"
}

# Custom prompt with colors following format: (.venv)user-workdir(branch) or user(project:namespace)-workdir(branch)
# Overrides the oh-my-zsh theme prompt (must stay below `source $ZSH/oh-my-zsh.sh`)
autoload -U colors && colors
setopt PROMPT_SUBST

PROMPT='$(context_prefix)%F{84}%n%f$(context_suffix)$(dir_with_separator)%F{135}$(git_branch)%f$ '


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
