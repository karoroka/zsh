#!/usr/bin/env bash

# Script for setup of zsh shell with prezto, zplug, powerlevel10k ...
# inspired by https://raw.githubusercontent.com/JGroxz/presto-prezto/refs/heads/main/presto-prezto.sh

GITREPO="https://raw.githubusercontent.com/karoroka/zsh/refs/heads"
ZDOTDIR="$HOME/.zsh"

init_Linux() {
    echo "--> Please, type your password (to 'sudo apt install' the requirements):"
    sudo apt-get update -y
    sudo apt-get install -y zsh git
    echo -e "\nInstalling zsh, git"
}

init_Darwin() {
    version_gt() {
        [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -gt "${2#*.}" ]]
    }

    version_ge() {
        [[ "${1%.*}" -gt "${2%.*}" ]] || [[ "${1%.*}" -eq "${2%.*}" && "${1#*.}" -ge "${2#*.}" ]]
    }

    major_minor() {
        echo "${1%%.*}.$(
            x="${1#*.}"
            echo "${x%%.*}"
        )"
    }

    macos_version="$(major_minor "$(/usr/bin/sw_vers -productVersion)")"

    should_install_command_line_tools() {
        if version_gt "$macos_version" "10.13"; then
            ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]]
        else
            ! [[ -e "/Library/Developer/CommandLineTools/usr/bin/git" ]] ||
                ! [[ -e "/usr/include/iconv.h" ]]
        fi
    }

    if should_install_command_line_tools && version_ge "$macos_version" "10.13"; then
        echo "--> When prompted for the password, enter your Mac login password."
        shell_join() {
            local arg
            printf "%s" "$1"
            shift
            for arg in "$@"; do
                printf " "
                printf "%s" "${arg// /\ }"
            done
        }
        chomp() {
            printf "%s" "${1/"$'\n'"/}"
        }
        have_sudo_access() {
            local -a args
            if [[ -n "${SUDO_ASKPASS-}" ]]; then
                args=("-A")
            elif [[ -n "${NONINTERACTIVE-}" ]]; then
                args=("-n")
            fi
        }
        have_sudo_access() {
            local -a args
            if [[ -n "${SUDO_ASKPASS-}" ]]; then
                args=("-A")
            elif [[ -n "${NONINTERACTIVE-}" ]]; then
                args=("-n")
            fi

            if [[ -z "${HAVE_SUDO_ACCESS-}" ]]; then
                if [[ -n "${args[*]-}" ]]; then
                    SUDO="/usr/bin/sudo ${args[*]}"
                else
                    SUDO="/usr/bin/sudo"
                fi
                if [[ -n "${NONINTERACTIVE-}" ]]; then
                    ${SUDO} -l mkdir &>/dev/null
                else
                    ${SUDO} -v && ${SUDO} -l mkdir &>/dev/null
                fi
                HAVE_SUDO_ACCESS="$?"
            fi

            if [[ -z "${HOMEBREW_ON_LINUX-}" ]] && [[ "$HAVE_SUDO_ACCESS" -ne 0 ]]; then
                abort "Need sudo access on macOS (e.g. the user $USER needs to be an Administrator)!"
            fi

            return "$HAVE_SUDO_ACCESS"
        }
        execute() {
            if ! "$@"; then
                abort "$(printf "Failed during: %s" "$(shell_join "$@")")"
            fi
        }
        execute_sudo() {
            local -a args=("$@")
            if have_sudo_access; then
                if [[ -n "${SUDO_ASKPASS-}" ]]; then
                    args=("-A" "${args[@]}")
                fi
                execute "/usr/bin/sudo" "${args[@]}"
            else
                execute "${args[@]}"
            fi
        }

        TOUCH="/usr/bin/touch"
        clt_placeholder="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
        execute_sudo "$TOUCH" "$clt_placeholder"
        clt_label_command="/usr/sbin/softwareupdate -l |
                            grep -B 1 -E 'Command Line Tools' |
                            awk -F'*' '/^ *\\*/ {print \$2}' |
                            sed -e 's/^ *Label: //' -e 's/^ *//' |
                            sort -V |
                            tail -n1"

        clt_label="$(chomp "$(/bin/bash -c "$clt_label_command")")"

        if [[ -n "$clt_label" ]]; then
            printf "Xcode Command Line Tools not found\nInstalling...\n"
            execute_sudo "/usr/sbin/softwareupdate" "-i" "$clt_label" &>/dev/null
            execute_sudo "/bin/rm" "-f" "$clt_placeholder" &>/dev/null
            execute_sudo "/usr/bin/xcode-select" "--switch" "/Library/Developer/CommandLineTools" &>/dev/null
        fi
    fi
}

config_Shell_Linux(){
    echo "Shell Configuration"

    if [[ "$SHELL" =~ "zsh" ]]; then
        echo "zsh is already your standard Shell"
    else
        chsh -s /bin/zsh &>/dev/null
    fi
}

config_Shell_Darwin(){
    echo "Shell Configuration"

    if [[ "$SHELL" =~ "zsh" ]]; then
        echo "zsh is already your standard Shell"
    else
        chsh -s /bin/zsh &>/dev/null
    fi
}

install_prezto(){
    if [ ! -d "$ZDOTDIR/.zprezto" ]; then
        echo -e "\ninstalling prezto"
        
        git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"
        
        echo -e "\ncreating prezto symlinks"
        # ln -sfv "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zlogin" "${ZDOTDIR:-$HOME}/.zlogin"
        # ln -sfv "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zlogout" "${ZDOTDIR:-$HOME}/.zlogout"
        ln -sfv "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zpreztorc" "${ZDOTDIR:-$HOME}/.zpreztorc"
        ln -sfv "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zprofile" "${ZDOTDIR:-$HOME}/.zprofile"
        #ln -sfv "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshenv" "${ZDOTDIR:-$HOME}/.zshenv"
        ln -sfv "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshrc" "${ZDOTDIR:-$HOME}/.zshrc"
    fi
}

install_zplug(){
    if [ ! -d "$ZDOTDIR/.zplug" ]; then
        echo -e "\ninstalling zplug..."
        git clone https://github.com/zplug/zplug "${ZDOTDIR:-$HOME}/.zplug"
    fi
}

download_with_curl(){
    source=$2
    destination=$1

    test_source=$(curl -o /dev/null --silent -Iw '%{http_code}' "$source")
    
    if [[ $test_source =~ "200" ]]; then
        curl --silent -o $destination $source
        echo "curl config from git: $destination"
    else
        echo "can not download $source - curl http result: $test_source"
    fi
}

got_runcoms(){
    # curl -o "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zlogin" "$GITREPO/main/zlogin"
    # curl -o "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zlogout" "$GITREPO/main/zlogout"
    download_with_curl "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zpreztorc" "$GITREPO/main/runcoms/zpreztorc"
    download_with_curl "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zprofile" "$GITREPO/main/runcoms/zprofile"
    # curl -o "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshenv" "$GITREPO/main/zshenv"
    download_with_curl "${ZDOTDIR:-$HOME}/.zprezto/runcoms/zshrc" "$GITREPO/main/runcoms/zshrc"
}

got_powerlevel_config(){
    curl -o "${ZDOTDIR:-$HOME}/.p10k.zsh" "$GITREPO/main/p10k.zsh"
}

main(){
    OS="$(uname)"

    if [[ "$OS" == "Linux" ]] || [[ "$OS" == "Darwin" ]]; then
        echo "detecting $OS"

        if [[ "$OS" == "Linux" ]]; then
            init_Linux
            config_Shell_Linux
        fi

        if [[ "$OS" == "Darwin" ]]; then
            init_Darwin
            config_Shell_Darwin
        fi
    else
        echo "This script is only supported on macOS and Linux."
        exit 0
    fi

    install_prezto
    install_zplug
    got_runcoms
    got_powerlevel_config

    echo "ZDOTDIR=$ZDOTDIR" > "$HOME/.zshenv"

    echo "RESTART TERMINAL"
}

main
