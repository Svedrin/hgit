#!/bin/bash

set -e
set -u
set -x

. ~/.hgitrc

COMMAND=""

while [ -n "${1:-}" ]; do
    case "$1" in
        -h|--help)
            echo  "Human-friendly git. (YMMV.)"
            echo
            echo  "Usage: $0 [options] [command] [arguments]"
            echo
            echo  "Options:"
            echo  " -h --help             This help text"
            echo
            echo  "Commands:"
            echo
            echo  " status, st            Show status of the workdir in way-too-long or nicely-short form."
            echo
            echo  " init                  Initialize a new git repo in a directory."
            echo  " create                Create a new repo in GitHub and run '$0 fork' on it."
            echo  " clone                 Clone a remote repo, plus your fork if you have one."
            echo  " fork                  Clone a remote repo, plus create a fork if you do NOT have one."
            echo  " branch, b             Create a new branch."
            echo  " branches              List existing branches."
            echo  " use                   Switch to an existing branch, even if it only exists in your"
            echo  "                       fork but not yet locally."
            echo
            echo  " diff, d               Diff workdir."
            echo  " diff-cached, dc       Diff staging area."
            echo  " commit, ci            Commit."
            echo  " change, c             Diff-or-commit (see its --help)."
            echo  " log                   Show logs."
            echo  " tag                   Create a tag and push it upstream."
            echo  " amend                 Amend stuff to the last commit, unless you pushed it already."
            echo  " push                  Push changes to a fork or upstream."
            echo  " pull                  Pull changes from a fork or upstream."
            echo  " pr                    Open a Pull Request."
            echo
            echo  " add                   Add a file to the repo, or add its changes to the staging area."
            echo  " cp                    Copy src to dest, then add dest to git."
            echo  " mv                    Move or rename a file, or record that you did that already."
            echo  " rm                    Remove a file."
            echo  " forget                Un-add/cp/mv/rm a file without touching the workdir."
            echo  " view                  View a file on GitHub."
            echo
            exit 0
            ;;

        -*)
            echo "Unknown option $1, see --help"
            exit 1
            ;;

        *)
            COMMAND="$1"
            shift
            break
            ;;
    esac
    shift
done


function hgit_status () {
    git status "$@"
}

function hgit_st () {
    git status --short --branch "$@"
}

function hgit_d {
    git diff --no-prefix "$@"
}

function hgit_dc {
    git diff --no-prefix --cached "$@"
}

function hgit_ci {
    git commit "$@"
}

function hgit_forget {
    git reset HEAD "$@"
}

function hgit_pull {
    git pull "$@"
}

function hgit_push {
    git push "$@"
}

function hgit_psuh {
    hgit_push "$@"
}

function hgit_puhs {
    hgit_push "$@"
}

function hgit_log {
    git log --color=always -- "$@" | less -RF
}


function hgit_use () {
    if [ "$1" = "master" ] && [ -z "${2:-}" ]; then
        git checkout master
        git fetch -p "${MY_GITHUB_USER,,}"
        return
    elif [ -z "${2:-}" ]; then
        # one arg:  123-something
        REMOTE="${MY_GITHUB_USER,,}"
        SEARCH="$1"
    else
        # two args: some-person 123-something
        REMOTE="${1,,}"
        SEARCH="$2"
    fi
    BRANCH="$(git ls-remote --heads "$REMOTE" | cut -d/ -f3 | grep "$SEARCH")"
    git fetch "$REMOTE" "$BRANCH"
    git checkout "$BRANCH"
}

if [ ! -n "$COMMAND" ]; then
    echo "need a command, see --help"
    exit 1
fi

if [ "$(type -t "hgit_$COMMAND")" != "function" ]; then
    echo "command $COMMAND is not defined, see --help"
    exit 1
fi

"hgit_$COMMAND" "$@"
