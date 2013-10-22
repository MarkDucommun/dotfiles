source /usr/local/etc/bash_completion.d/git-prompt.sh

RED="\[\e[1;31m\]"
GREEN="\[\e[1;32m\]"
NO_COLOR="\[\e[0m\]"
START_OF_LINE="\[\033[G\]"

scm_ps1() {
    local s=
    if [[ -d ".svn" ]] ; then
        s=\ \(svn:$(svn info | sed -n -e '/^Revision: \([0-9]*\).*$/s//\1/p' )\)
    else
        GIT_PS1_SHOWDIRTYSTATE=true
        s=$(__git_ps1 " (git:%s)")
    fi
    echo -n "$s"
}

export GIT_PS1_SHOWDIRTYSTATE=true
export PS1="$NO_COLOR\u:\W$GREEN\$(__git_ps1)$NO_COLOR $ "
