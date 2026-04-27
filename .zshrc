
export EDITOR=/usr/bin/nano                     # Set Default Editor (change 'Nano' to the editor of your choice)
export BLOCKSIZE=1k                             # Set default blocksize for ls, df, du

eval "$(/opt/homebrew/bin/brew shellenv)"       # Set PATH, MANPATH, etc., for Homebrew.
eval "$(starship init zsh)"                     # Setup starship prompt
eval "$(direnv hook zsh)"                       # Add hooks for direnv
setopt CORRECT                                  # Replacement for cdspell (spelling correction)
setopt EXTENDED_GLOB                            # Replacement for extglob
setopt APPEND_HISTORY                           # Replacement for histappend (usually default)
setopt HIST_VERIFY                              # Replacement for histverify
setopt AUTO_CD                                  # you can just type .. or even a folder name like Downloads without typing cd first, and Zsh will just go there.
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'     # Case-insensitive tab completion
zstyle ':completion:*' menu select                      # Arrow-key selectable completion menu

alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
# restoredotfiles: bootstrap dotfiles on a fresh machine from github.com/duncsm/dotfiles
# Chicken-and-egg note: this function lives in the .zshrc you're trying to restore,
# so on a *brand new* machine you won't have it yet. Two ways to bootstrap:
#   1. Run the commands below by hand (or copy them from the GitHub repo), or
#   2. One-liner:
#      git clone --bare git@github.com:duncsm/dotfiles.git ~/.dotfiles && \
#        git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout && \
#        git --git-dir=$HOME/.dotfiles --work-tree=$HOME config --local status.showUntrackedFiles no
# Once .zshrc is restored and a new shell is started, `restoredotfiles` is available
# for re-running on subsequent machines.
restoredotfiles () {
    local repo="git@github.com:duncsm/dotfiles.git"
    local gitdir="$HOME/.dotfiles"
    local backup="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

    if [ -d "$gitdir" ]; then
        echo "Error: $gitdir already exists. Aborting to avoid clobbering."
        return 1
    fi

    echo "Cloning $repo into $gitdir..."
    git clone --bare "$repo" "$gitdir" || return 1

    local dot="git --git-dir=$gitdir --work-tree=$HOME"

    # Try checkout; if it fails because files already exist (e.g. macOS default .zshrc),
    # back them up and retry.
    if ! eval "$dot checkout" 2>/dev/null; then
        echo "Checkout conflicts — backing up clashing files to $backup"
        mkdir -p "$backup"
        eval "$dot checkout" 2>&1 | \
            grep -E "^\s+\S" | awk '{print $1}' | \
            while read -r f; do
                mkdir -p "$backup/$(dirname "$f")"
                mv "$HOME/$f" "$backup/$f"
            done
        eval "$dot checkout" || { echo "Checkout still failing — see $backup"; return 1; }
    fi

    eval "$dot config --local status.showUntrackedFiles no"
    echo "Done. Open a new shell to pick up the restored config."
}

alias cp='cp -iv'                               # Preferred 'cp' implementation
alias mv='mv -iv'                               # Preferred 'mv' implementation
alias mkdir='mkdir -pv'                         # Preferred 'mkdir' implementation
alias ls='ls -G'                                # Preferred basic 'ls' implementation
alias ll='ls -FGlAhp'                           # Preferred 'ls' implementation
alias less='less -FSRXc'                        # Preferred 'less' implementation
alias cd..='cd ../'                             # Go back 1 directory level (for fast typers)
alias ..='cd ../'                               # Go back 1 directory level
alias ...='cd ../../'                           # Go back 2 directory levels
alias .3='cd ../../../'                         # Go back 3 directory levels
alias .4='cd ../../../../'                      # Go back 4 directory levels
alias .5='cd ../../../../../'                   # Go back 5 directory levels
        alias .6='cd ../../../../../../'                # Go back 6 directory levels
alias edit='subl'                               # edit:         Opens any file in sublime editor
alias f='open -a Finder ./'                     # f:            Opens current directory in MacOS Finder
alias ~="cd ~"                                  # ~:            Go Home
alias c='clear'                                 # c:            Clear terminal display
alias path='echo $PATH | tr ":" "\n"'           # path:         Echo all executable Paths
alias fix_stty='stty sane'                      # fix_stty:     Restore terminal settings when screwed up
alias brewfull='brew update && brew upgrade && brew cleanup'
alias lg='lazygit'                              # quicky shortcut for launching lazygit
alias lgdf='GIT_DIR=$HOME/.dotfiles GIT_WORK_TREE=$HOME lazygit'

mcd () { mkdir -p "$1" && cd "$1"; }            # mcd:          Makes new Dir and jumps inside
trash () { command mv "$@" ~/.Trash ; }         # trash:        Moves a file to the MacOS trash
ql () { qlmanage -p "$@" >& /dev/null; }        # ql:           Opens any file in MacOS Quicklook Preview

zipf () { zip -r "$1".zip "$1" ; }          # zipf:         To create a ZIP archive of a folder
alias numFiles='ls -1 *(.) | wc -l'         # numFiles:     Count of non-hidden files in current dir
alias make1mb='mkfile 1m ./1MB.dat'         # make1mb:      Creates a file of 1mb size (all zeros)
alias make5mb='mkfile 5m ./5MB.dat'         # make5mb:      Creates a file of 5mb size (all zeros)
alias make10mb='mkfile 10m ./10MB.dat'      # make10mb:     Creates a file of 10mb size (all zeros)

# cdf:  'Cd's to frontmost window of MacOS Finder
cdf () {
    currFolderPath=$( /usr/bin/osascript <<EOT
        tell application "Finder"
            try
        set currFolder to (folder of the front window as alias)
            on error
        set currFolder to (path to desktop folder as alias)
            end try
            POSIX path of currFolder
        end tell
EOT
    )
    echo "cd to \"$currFolderPath\""
    cd "$currFolderPath"
}

# extract:  Extract most know archives with one command
    extract () {
        if [ -f "$1" ] ; then
          case $1 in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
             esac
         else
             echo "'$1' is not a valid file"
         fi
    }

# SEARCHING
alias qfind='find -x . -name'                               # qfind: Quickly search for file
ff () { /usr/bin/find . -name "$1" ; }                      # ff: Find file under the current directory
ffa () { /usr/bin/find . -name "*$1*" ; }                   # ffa: Find file whose name contains a given string
ffs () { /usr/bin/find . -name "$1*" ; }                    # ffs: Find file whose name starts with a given string
ffe () { /usr/bin/find . -name "*$1" ; }                    # ffe: Find file whose name ends with a given string
spotlight () { mdfind "kMDItemDisplayName == '$*'c" ; }     # spotlight: Search for a file using MacOS Spotlight's metadata

# NETWORKING
alias myip='curl -s http://checkip.amazonaws.com'              # myip: Public IP
myips() {
  local ts_ip=$(tailscale ip -4 2>/dev/null)
  local docker_bridges=$(ifconfig -l | tr ' ' '\n' | grep '^bridge' | while read br; do
    ifconfig "$br" 2>/dev/null | grep -q vmenet && echo "$br"
  done)

  echo "Local:"
  ifconfig | awk '/^[a-z]/{iface=$1} /inet /{print iface, $2}' | grep -v 127.0.0.1 | while read iface ip; do
    iface=${iface%:}
    local label="$iface"
    case "$iface" in
      en0) label="WiFi" ;;
      en*) label="Ethernet ($iface)" ;;
      bridge*)
        if echo "$docker_bridges" | grep -q "^${iface}$"; then
          label="Docker ($iface)"
        else
          label="Bridge ($iface)"
        fi ;;
      utun*)
        if [ -n "$ts_ip" ] && [ "$ip" = "$ts_ip" ]; then
          label="Tailscale ($iface)"
        elif [[ "$ip" == 100.* ]]; then
          label="WireGuard ($iface)"
        else
          label="Tunnel ($iface)"
        fi ;;
    esac
    echo "  $label: $ip"
  done

  local wan=$(dig +short myip.opendns.com @208.67.222.222)
  echo "WAN: $wan"
  local ts=$(curl -s --connect-timeout 3 checkip.amazonaws.com)
  if [ -n "$ts" ] && [ "$ts" != "$wan" ]; then
    echo "Tailscale: $ts"
  fi
  local pub=$(curl -s --connect-timeout 3 ifconfig.me)
  if [ -n "$pub" ] && [ "$pub" != "$wan" ] && [ "$pub" != "$ts" ]; then
    echo "Netskope: $pub"
  fi
}
alias netCons='lsof -i'                                          # netCons: Open sockets
alias flushDNS='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder' # flushDNS: Modern macOS fix
alias lsock='sudo /usr/sbin/lsof -i -P'                          # lsock: Open sockets
alias lsockU='sudo /usr/sbin/lsof -nP | grep UDP'                # lsockU: UDP only
alias lsockT='sudo /usr/sbin/lsof -nP | grep TCP'                # lsockT: TCP only
alias ipInfo0='ipconfig getpacket en0'                           # ipInfo0: en0 info
alias ipInfo1='ipconfig getpacket en1'                           # ipInfo1: en1 info
alias openPorts='sudo lsof -i | grep LISTEN'                     # openPorts: Listening
alias showBlocked='sudo pfctl -sr'                               # showBlocked: pf rules (replaces ipfw)

# Define colors for the ii() function if they aren't already in your file
RED=$'\e[1;31m'
NC=$'\e[0m'
ii() {
    echo -e "\nYou are logged on ${RED}$HOST${NC}"
    echo -e "\nAdditional information:${NC} " ; uname -a
    echo -e "\n${RED}Users logged on:${NC} " ; w -h
    echo -e "\n${RED}Current date :${NC} " ; date
    echo -e "\n${RED}Machine stats :${NC} " ; uptime
    echo -e "\n${RED}Current network location :${NC} " ; scselect
    echo
}

# SYSTEMS OPERATIONS & INFORMATION
alias cleanupDS="find . -type f -name '.DS_Store' -ls -delete"      # cleanupDS: Recursively delete .DS_Store files
alias fix_open_with='/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -r -domain local -domain system -domain user && killall Finder'

fpath=(/Users/duncansmith/.docker/completions $fpath)

alias d='docker'                                         # d: Shortcut
alias co='docker container list -a'                      # co: List all containers
alias dip="docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'"

# Load machine-specific or sensitive settings
if [ -f "$HOME/.zshrc_local" ]; then
    source "$HOME/.zshrc_local"
fi

