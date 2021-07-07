#!/bin/bash

set -e
set -u



if [ "${RUNNING_IN_CI:-false}" = "false" ]; then
    if [ ! -f ~/.hgitrc ]; then
        if [ -z "${USER:-}" ]; then
            USER="$(id -u -n)"
        fi
        # ~/.hgitrc is missing. See if we're running in a tty, and
        # if so, offer to create it - otherwise bail
        if [ -t 0 ]; then
            echo -n "Configuring hgit in ~/.hgitrc. What is your GitHub username? [$USER] "
            read GHUSER
            echo "MY_GITHUB_USER=${GHUSER:-$USER}" > ~/.hgitrc
        else
            echo "Please create ~/.hgitrc to configure your GitHub username:"
            echo 'echo MY_GITHUB_USER="your username here" > ~/.hgitrc'
            exit 2
        fi
    fi

    . ~/.hgitrc

    REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
    MASTER_BRANCH="master"

    if [ -e "$REPO_ROOT/.git/hgitrc" ]; then
        . "$REPO_ROOT/.git/hgitrc"
    fi

    COMMAND=""

    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo  "Human-friendly git."
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
                echo  " clone                 Clone a remote repo, plus your fork if you have one."
                echo  " collab-with           Add a remote for collaborating with another GitHub user."
                echo  " branch, b, br         Create a new branch."
                echo  " branch-from           Create a new branch from a specific commit or tag."
                echo  " branches, bs          List existing branches, either local ones or those in a remote."
                echo  " use                   Switch to an existing branch, even if it only exists in your"
                echo  "                       fork but not yet locally."
                echo  " kill                  Delete a branch."
                echo
                echo  " diff, d               Diff workdir."
                echo  " diff-staging, ds, dc  Diff staging area."
                echo  " commit, ci            Commit."
                echo  " uncommit              Undo the last commit, unless you pushed it already. Does not"
                echo  "                       modify your workdir, changes are uncommited but not undone."
                echo  " change, c             Diff-or-commit (see its --help)."
                echo  " log                   Show logs."
                echo  " tag                   Create a tag and push it upstream."
                echo  " tags                  List existing tags."
                echo  " amend                 Amend stuff to the last commit, unless you pushed it already."
                echo  " push                  Push changes to a fork or upstream."
                echo  " pull                  Pull changes from a fork or upstream."
                echo  " pr                    Open a Pull Request."
                echo
                echo  " add                   Add a file to the repo, or add its changes to the staging area."
                echo  " cp                    Copy src to dest, then add dest to git."
                echo  " mv                    Move or rename a file, or record that you did that already."
                echo  " rm                    Remove a file."
                echo  " cat                   Dump files from the repo to stdout."
                echo  " touch                 Create or touch a file, creating all its parent directories."
                echo  " forget                Un-add/cp/mv/rm a file without touching the workdir."
                echo  " revert, re            Undo your changes and set the file to the latest state in the"
                echo  "                       repo or staging area."
                echo  " ignore                Add a path to .gitignore."
                echo  " gh                    View files on GitHub."
                echo
                echo  "See \`$0 <command> --help\` for help on specific commands."
                echo
                exit 0
                ;;

            -*)
                echo "Unknown option $1, see --help"
                exit 1
                ;;

            *)
                COMMAND="${1/-/_}"
                shift
                break
                ;;
        esac
        shift
    done
fi

# Helper functions

function hgit_my_fork {
    echo "${MY_GITHUB_USER,,}"
}

function hgit_have_remote {
    git remote | grep -q "^$1\$"
}

function hgit_have_fork {
    hgit_have_remote "$(hgit_my_fork)"
}

function hgit_remote_for_branch {
    BRANCH="$1"
    git branch --format='%(refname:short) %(upstream:remotename)' | while read branch remote; do
        if [ "$branch" = "$BRANCH" ] && [ -n "$remote" ]; then
            echo "$remote"
            break
        fi
    done
}

function hgit_last_commit_not_yet_pushed {
    CURR_BRANCH="$(hgit_branch)"
    REMOTE="$(hgit_remote_for_branch "$CURR_BRANCH")"
    if [ -z "$REMOTE" ]; then
        # if the branch doesn't even _have_ a remote, we probably haven't pushed
        return 0
    fi
    LAST_COMMIT="$(git log --format="%H" -n 1)"
    git rev-list --left-right "$CURR_BRANCH"..."$REMOTE"/"$CURR_BRANCH" | \
        grep -q "^<$LAST_COMMIT\$"
}

# Init, clone

function hgit_init {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Create a new git repo in a directory."
        echo
        echo "Usage: hgit init [-h|--help] [<target dir>]"
        echo
        echo "Target dir defaults to '.' (the current directory)."
        return
    fi
    REPO="$(realpath "${1:-$PWD}")"
    if [ -e "$REPO/.git" ]; then
        echo "$REPO already is a git repository, not doing anything." >&2
        return 1
    fi
    git init "$REPO"
}

function hgit_clone {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Clone an existing repo, and if it's from GitHub and you"
        echo "have a fork, clone that too."
        echo
        echo "Usage: hgit clone [-h|--help] git@github.com:<owner>/<repo>.git [<target dir>]"
        echo
        echo "The magic that checks out your fork only works with GitHub and only"
        echo "with SSH URLs. Other URLs are checked out as well, but they are"
        echo "passed on to git as they are without trying to do anything clever."
        echo ""
        echo "You can abbreviate GitHub URLs: 'hgit clone gh:<owner>/<repo> will be"
        echo "expanded to mean 'hgit clone git@github.com:<owner>/<repo>.git'."
        return
    fi

    URL="$1"

    # Expand an abbreviated GitHub URL
    if [ "$(cut -c -3 <<<"$URL")" = "gh:" ]; then
        OWNER_AND_REPO="$(cut -c 4- <<<"$URL")"
        OWNER="$(cut -d/ -f1 <<<"$OWNER_AND_REPO")"
        REPO="$(cut -d/ -f2 <<<"$OWNER_AND_REPO")"
        URL="git@github.com:${OWNER}/${REPO}.git"
    fi

    # See if this even is a GitHub repo at all
    if [ "$(cut -c -15 <<<"$URL")" != "git@github.com:" ]; then
        git clone "$1"
        echo "Sorry, not a GitHub repo, so I don't know how to check for forks 'n stuff."
        echo "I did clone the repo for you though."
        return
    fi

    OWNER_AND_REPO="$(cut -c 16- <<<"$URL")"
    OWNER="$(cut -d/ -f1 <<<"$OWNER_AND_REPO")"
    REPO="$(cut -d/ -f2 <<<"$OWNER_AND_REPO" | sed 's/.git$//')"
    INTO="${2:-${REPO,,}}"

    git clone "$URL" "$INTO"

    cd "$INTO"

    # See if master has been renamed in this repo, and if so,
    # generate a .git/hgitrc file to reflect that
    CURR_BRANCH="$(hgit_branch)"
    if [ "$CURR_BRANCH" != "master" ]; then
        printf 'MASTER_BRANCH="%s"\n' "$CURR_BRANCH" > .git/hgitrc
    fi

    # If this is not our repo, see if we have a fork, and if so,
    # add it as a remote
    if [ "$OWNER" != "$MY_GITHUB_USER" ]; then
        MY_REMOTE_URL="git@github.com:${MY_GITHUB_USER}/${REPO}.git"
        if git ls-remote --heads "$MY_REMOTE_URL" &>/dev/null; then
            git remote add "$(hgit_my_fork)" "$MY_REMOTE_URL"
            git fetch "$(hgit_my_fork)"
        fi
    fi
}

function hgit_collab_with {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Set up the repo so we can collaborate with another GitHub user."
        echo
        echo "Usage: hgit collab-with [-h|--help] <GitHub user>"
        return
    fi

    COLLAB_USER="$1"

    ORIGIN_URL="$(git remote get-url "origin")"
    # See if this even is a GitHub repo at all
    if [ "$(cut -c -15 <<<"$ORIGIN_URL")" != "git@github.com:" ]; then
        echo "Sorry, not a GitHub repo, so I don't know how to collab with people here."
        return
    fi

    ORIGIN_OWNER_AND_REPO="$(cut -c 16- <<<"$ORIGIN_URL")"
    ORIGIN_REPO="$(cut -d/ -f2 <<<"$ORIGIN_OWNER_AND_REPO" | sed 's/.git$//')"

    REMOTE_URL="git@github.com:${COLLAB_USER}/${ORIGIN_REPO}.git"
    if git ls-remote --heads "$REMOTE_URL" &>/dev/null; then
        git remote add "${COLLAB_USER,,}" "$REMOTE_URL"
    fi
}

function hgit_checkout {
    echo "The checkout command has no power here. You're probably looking for one of these:"
    echo
    echo  " branch, b             Create a new branch."
    echo  " branch-from           Create a new branch from a specific commit or tag."
    echo  " use                   Switch to an existing branch, even if it only exists in your"
    echo  "                       fork but not yet locally."
    echo  " revert, re            Undo your changes and set the file to the latest state in the"
    echo  "                       repo or staging area."
}

function hgit_co {
    hgit_checkout "$@"
}

# Status

function hgit_status {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Show the current status of the working directory and which branch we're in."
        echo "Uses a pretty verbose syntax, see \`hgit st\` for a shorter one."
        echo
        echo "Usage: hgit status [-h|--help]"
        return
    fi
    git status
}

function hgit_st {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Show the current status of the working directory and which branch we're in."
        echo "Uses a pretty concise syntax, see \`hgit status\` for a more verbose one."
        echo
        echo "Usage: hgit st [-h|--help]"
        return
    fi
    git status --short --branch
}

# Diff

function hgit_diff {
    COMMIT=""
    OPTS=""
    FILES=()
    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "View differences of a file in the workdir vs the one in the repo."
                echo
                echo "Usage: hgit diff [-c <commit ID>] [files]"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -s --staging          Show staged changes rather than those from the workdir."
                echo " -c --commit           Show changes made in a certain commit."
                echo " -w --no-whitespace    Do not include lines that only change whitespace in the diff."
                return
                ;;
            -c|--commit)
                COMMIT="$2"
                shift
                ;;
            -w|--no-whitespace)
                OPTS="$OPTS -w"
                ;;
            -s|--staging)
                OPTS="$OPTS --cached"
                ;;
            *)
                FILES+=("$1")
                ;;
        esac
        shift
    done
    if [ -n "$COMMIT" ]; then
        git diff --no-prefix $OPTS "$COMMIT^" "$COMMIT" -- "${FILES[@]}"
    else
        git diff --no-prefix $OPTS -- "${FILES[@]}"
    fi
}

function hgit_d {
    hgit_diff "$@"
}

function hgit_diff_staging {
    hgit_diff --staging "$@"
}

function hgit_dc {
    hgit_diff_staging "$@"
}

function hgit_ds {
    hgit_diff_staging "$@"
}

# Commit

function hgit_commit {
    MESSAGE=""
    FILES=()
    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "Commit changes from the workdir. If no files are given, commits"
                echo "whatever is currently in the staging area. See \`hgit diff-staging\`"
                echo "to check what's in there."
                echo
                echo "Usage: hgit commit [-m <commit message>] [files]"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -m --message          Commit changes with the specified message."
                return
                ;;
            -m|--message)
                MESSAGE="$2"
                shift
                ;;
            -*)
                echo "Unknown option $1"
                return 1
                ;;
            *)
                FILES+=("$1")
                ;;
        esac
        shift
    done
    if hgit_have_fork && [ "$(hgit_branch)" = "$MASTER_BRANCH" ]; then
        echo "You have a fork and you're commiting to $MASTER_BRANCH. You probably don't want to do that, aborting."
    elif [ -n "$MESSAGE" ]; then
        git commit -m "$MESSAGE" -- "${FILES[@]}"
    else
        git commit -- "${FILES[@]}"
    fi
}

function hgit_ci {
    hgit_commit "$@"
}

function hgit_change {
    #set -x
    MESSAGE=""
    FILES=()
    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "View or commit changes from the workdir."
                echo
                echo "Usage: hgit change [-m <commit message>] [files]"
                echo
                echo "If no files are given, displays 'hgit st'."
                echo "If one or more files are given, diffs those files."
                echo "If files and -m is given, these files are commited."
                echo "Order of files and options does not matter."
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -m --message          Commit changes with the specified message."
                echo
                echo "A typical workflow could be:"
                echo
                echo " :~/repo$ echo test >> somefile.txt"
                echo " :~/repo$ h c"
                echo " ## master"
                echo " ??  somefile.txt"
                echo " :~/repo$ h add somefile.txt"
                echo " :~/repo$ h c somefile.txt"
                echo " diff --git somefile.txt somefile.txt"
                echo " new file mode 100644"
                echo " index 0000000..19044b6"
                echo " --- /dev/null"
                echo " +++ somefile.txt"
                echo " @@ -0,0 +1 @@"
                echo " +test"
                echo " :~/repo$ h c somefile.txt -m 'add some file'"
                echo " [master e20d9ac] add some file"
                echo "  1 file changed, 1 insertion(+)"
                echo "  create mode 100644 somefile.txt"
                echo " :~/repo$ h c"
                echo " ## master"
                return
                ;;
            -m|--message)
                MESSAGE="$2"
                shift
                ;;
            *)
                FILES+=("$1")
                ;;
        esac
        shift
    done
    if [ "${#FILES[*]}" = "0" ]; then
        hgit_st
    elif [ -n "$MESSAGE" ]; then
        hgit_commit -m "$MESSAGE" "${FILES[@]}"
    else
        hgit_diff_staging "${FILES[@]}"
        hgit_diff "${FILES[@]}"
    fi
}

function hgit_c {
    hgit_change "$@"
}

function hgit_amend {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Amend changes to the last commit."
        echo
        echo "Usage: hgit amend <files...>"
        echo
        echo "Most useful when you forgot to include something."
        return
    fi
    if hgit_last_commit_not_yet_pushed; then
        git commit --amend -- "$@"
    else
        echo "Sorry, you pushed that commit already, so others know about"
        echo "it. Changing it now is not a good idea anymore. Please just"
        echo "create another regular commit."
    fi
}

function hgit_uncommit {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Undo the last commit, unless you pushed it already."
        echo
        echo "Usage: hgit uncommit"
        echo
        echo "This does not modify your work directory: The changes are"
        echo "uncommited but not undone. If you want to also have them"
        echo "undone, follow this command with \`hgit revert\`."
        return
    fi
    if hgit_last_commit_not_yet_pushed; then
        git reset "HEAD~"
    else
        echo "Sorry, you pushed that commit already, so others know about"
        echo "it. Pretending it never happened is not a good idea anymore."
        echo
        echo "There's no obvious best solution to this situation: You can"
        echo "try to use \`git revert --no-commit\` though to put your"
        echo "workdir in a state with those changes reversed, and then"
        echo "commit that state of the workdir."
    fi
}

function hgit_tag {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Create a tag and push it to origin."
        echo
        echo "Usage: hgit tag [-h|--help] <tag> [<commit>]"
        return
    fi
    if [ -z "${2:-}" ]; then
        git tag -a "$1" -m "tag $1"
    else
        git tag -a "$1" -m "tag $1" "$2"
    fi
    git push origin "$1"
}

function hgit_tags {
    git tag -n
}


# Branches

function hgit_branches {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "List existing branches, either local ones or those in a remote."
        echo
        echo "Usage: hgit branches [-h|--help] [<remote>]"
        return
    fi
    REMOTE="${1:-}"
    if [ -n "$REMOTE" ]; then
        git ls-remote --heads "$REMOTE" | cut -d/ -f3
    else
        git branch -l
    fi
}

function hgit_bs {
    hgit_branches "$@"
}

function hgit_use {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Find and switch to an existing branch."
        echo
        echo "Usage: hgit use [-h|--help] [<remote>] <search term>"
        echo
        echo "If switching to '$MASTER_BRANCH' and a fork exists, an implicit"
        echo "sync is performed to remove local branches that have been"
        echo "deleted in the fork (e.g. after a PR is merged)."
        return
    fi
    if [ "$MASTER_BRANCH" != "master" ] && [ "$1" = "master" ]; then
        echo "In this repo, master is called $MASTER_BRANCH."
        echo "Please switch to that instead. If you really do"
        echo "want to switch to master, use git checkout master."
        return
    fi
    if [ -z "${2:-}" ]; then
        # one arg:  123-something
        if hgit_have_fork; then
            REMOTE="$(hgit_my_fork)"
        elif hgit_have_remote origin; then
            REMOTE="origin"
        fi
        SEARCH="$1"
    else
        # two args: some-person 123-something
        REMOTE="${1,,}"
        if ! hgit_have_remote "$REMOTE"; then
            echo "Remote $REMOTE does not exist" >&2
            return 1
        fi
        SEARCH="$2"
    fi
    # Are we explicitly checking out master?
    if [ "$SEARCH" = "$MASTER_BRANCH" ]; then
        git checkout "$MASTER_BRANCH"
        if hgit_have_fork; then
            # If we have a fork of this repo, prune branches that no longer exist in it
            git fetch -p $(hgit_my_fork)
        fi
        # pull from upstream
        git pull
        # Prune merged branches locally so that they are removed from git config
        for branch in $(git branch --merged "$MASTER_BRANCH" | cut -c 3-); do
            if [ "$branch" != "$MASTER_BRANCH" ]; then
                git branch -d "$branch"
            fi
        done
        return
    fi
    # Try to find the branch locally.
    CANDIDATES=($(git branch -l | cut -c3- | grep "$SEARCH" || true))
    if [ "${#CANDIDATES[*]}" = "1" ]; then
        if [ "${CANDIDATES[0]}" = "$MASTER_BRANCH" ]; then
            hgit_use "$MASTER_BRANCH"
        else
            git checkout "${CANDIDATES[0]}"
        fi
    elif [ "${#CANDIDATES[*]}" -gt "1" ]; then
        echo "Found multiple branches, please make your search term more specific:"
        for CAND in "${CANDIDATES[@]}"; do
            echo "$CAND"
        done
    elif [ -n "${REMOTE:-}" ]; then
        # Branch not found locally, but we have a fork: look there
        CANDIDATES=($(git ls-remote --heads "$REMOTE" | cut -d/ -f3 | grep "$SEARCH" || true))
        if [ "${#CANDIDATES[*]}" = "1" ]; then
            git fetch "$REMOTE" "${CANDIDATES[0]}"
            git checkout "${CANDIDATES[0]}"
        elif [ "${#CANDIDATES[*]}" -gt "1" ]; then
            echo "Found multiple branches, please make your search term more specific:"
            for CAND in "${CANDIDATES[@]}"; do
                echo "$CAND"
            done
        else
            echo "Branch found neither locally nor in $REMOTE :("
        fi
    else
        echo "Branch not found locally and there is no remote :("
    fi
}

function hgit_branch {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Show current branch or create a new one."
        echo
        echo "Usage: hgit branch [-h|--help] [<branch name>]"
        echo
        echo "If no branch name is given, shows which branch we're currently on."
        echo "If a branch name is given and it does not yet exist, it is created."
        echo "If a branch name is given and it exists already, we switch to it"
        echo "  (in this case, hgit branch is an alias to hgit use)."
        return
    elif [ -z "${1:-}" ]; then
        # No branch name given -> show current branch
        # "git branch --show-current" would do this, but requires recent git
        git branch | grep '^* ' | cut -c 3-
    elif git branch -l | cut -c3- | grep -q "^$1$"; then
        # Branch exists already, switch to it
        hgit_use "$1"
    else
        # Branch does not exist, create it - but make sure we're on master first
        if [ "$(git branch | grep '^* ' | cut -c 3-)" != "$MASTER_BRANCH" ]; then
            echo "You're creating a branch while you're not on $MASTER_BRANCH. You probably don't want to do that, aborting."
            echo "Try running 'hgit use $MASTER_BRANCH' and then repeating this command."
            exit 1
        fi
        git checkout -b "$1"
    fi
}

function hgit_b {
    hgit_branch "$@"
}

function hgit_br {
    hgit_branch "$@"
}

function hgit_branch_from {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Create a branch that starts at a given commit or tag and switch to it."
        echo
        echo "Usage: hgit branch-from [-h|--help] <branch name> <commit or tag>"
        return
    fi
    git branch "$1" "$2"
    hgit_use "$1"
}

function hgit_kill {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Delete a branch."
        echo
        echo "Usage: hgit kill [-h|--help] <branch name|--all>"
        return
    fi
    hgit_use "$MASTER_BRANCH"
    if [ "$1" = "--all" ]; then
        echo "This will delete all branches except $MASTER_BRANCH, are you sure?"
        echo "If yes, run $0 kill --all-yes-sure."
    elif [ "$1" = "--all-yes-sure" ]; then
        for branch in $(git branch -l | cut -c 3-); do
            if [ "$branch" != "$MASTER_BRANCH" ]; then
                git branch -D "$branch"
            fi
        done
    else
        git branch -D "$1"
    fi
}

# Push/pull

function hgit_pull {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Pull changes from a remote."
        echo
        echo "Usage: hgit pull [-h|--help] [<remote> [<branch>]|$MASTER_BRANCH]"
        echo
        echo "If remote and branch are both specified, we'll pull that branch from that remote."
        echo "If just a remote is given, we'll pull the current branch from that remote."
        echo "If just the word '$MASTER_BRANCH' is given, we'll pull origin $MASTER_BRANCH"
        echo "If nothing is given and we're on $MASTER_BRANCH, we'll pull origin $MASTER_BRANCH"
        echo "If nothing is given and we're not on $MASTER_BRANCH and we have a fork, we'll pull the current branch from there."
        echo "If nothing is given and we're not on $MASTER_BRANCH and we do not have a fork, we'll pull the current branch from origin."
        return
    fi
    CURR_BRANCH="$(hgit_branch)"
    # How many args do we have?
    if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
        # Two args: remote and branch
        REMOTE="$1"
        BRANCH="$2"
    elif [ "${1:-}" = "$MASTER_BRANCH" ]; then
        # One arg == master
        REMOTE="origin"
        BRANCH="$MASTER_BRANCH"
    elif [ -n "${1:-}" ]; then
        # One arg: Remote
        REMOTE="$1"
        BRANCH="$CURR_BRANCH"
    elif [ "$CURR_BRANCH" = "$MASTER_BRANCH" ]; then
        # No args, on master
        REMOTE="origin"
        BRANCH="$MASTER_BRANCH"
    elif hgit_have_fork; then
        # No args, not on master, and we have a fork
        REMOTE="$(hgit_my_fork)"
        BRANCH="$CURR_BRANCH"
    else
        # No args, not on master, no fork
        REMOTE="origin"
        BRANCH="$CURR_BRANCH"
    fi
    git pull "$REMOTE" "$BRANCH"
}

function hgit_push {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Push changes to a remote."
        echo
        echo "Usage: hgit push [-h|--help] [<remote>]"
        echo
        echo "If remote is specified, we'll push the current branch there."
        echo "If remote is not specified and we're on $MASTER_BRANCH, we'll push to origin $MASTER_BRANCH."
        echo "If remote is not specified and we're not on $MASTER_BRANCH and the current branch is already tracking a remote, we'll push there."
        echo "If remote is not specified and we're not on $MASTER_BRANCH and we have a fork, we'll push to the fork."
        echo "If remote is not specified and we're not on $MASTER_BRANCH and we do not have a fork, we'll push to origin."
        return
    fi
    CURR_BRANCH="$(hgit_branch)"
    # To see if we need to --set-upstream, find out which remote the current branch is tracking
    SET_UPSTREAM=""
    if [ -z "$(hgit_remote_for_branch "$CURR_BRANCH")" ]; then
        SET_UPSTREAM="--set-upstream"
    fi
    # Now push
    if [ -n "${1:-}" ]; then
        git push $SET_UPSTREAM "$1" "$CURR_BRANCH"
    elif [ "$CURR_BRANCH" = "$MASTER_BRANCH" ]; then
        if hgit_have_fork ; then
            echo "You have a fork and you're pushing to $MASTER_BRANCH. You probably don't want to do that, aborting."
            echo "If you do want to do this, run $0 push origin."
        else
            git push $SET_UPSTREAM "origin" "$MASTER_BRANCH"
        fi
    elif [ -n "$(hgit_remote_for_branch "$CURR_BRANCH")" ]; then
        git push
    elif hgit_have_fork; then
        git push $SET_UPSTREAM "$(hgit_my_fork)" "$CURR_BRANCH"
    else
        git push $SET_UPSTREAM "origin" "$CURR_BRANCH"
    fi
}

function hgit_psuh {
    hgit_push "$@"
}

function hgit_puhs {
    hgit_push "$@"
}

function hgit_spuh {
    hgit_push "$@"
}

# Log

function hgit_log {
    COMMIT=""
    FILES=()
    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "View the revision log."
                echo
                echo "Usage: hgit log [-c <commit ID>] [files]"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -c --commit           Show log only for a certain commit."
                echo
                echo "If files are given, only logs relevant to those files are shown."
                return
                ;;
            -c|--commit)
                COMMIT="$2"
                shift
                ;;
            *)
                FILES+=("$1")
                ;;
        esac
        shift
    done
    if [ -n "$COMMIT" ]; then
        git log --color=always "$COMMIT^..$COMMIT" -- "${FILES[@]}" | less -RF
    else
        git log --color=always -- "${FILES[@]}" | less -RF
    fi
}

function hgit_pr {
    DRY_RUN="false"
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Open the web browser to create a GitHub PR from the current branch."
        echo
        echo "Usage: hgit pr [-h|--help|-d|--dry-run] [<target branch>]"
        echo
        echo "Target branch defaults to $MASTER_BRANCH."
        echo
        echo "If you have not yet pushed your changes, this command will do it for you before opening the browser."
        echo
        echo "Options:"
        echo " -h --help             This help text"
        echo " -d --dry-run          Only print the URL, do not open the browser."
        if [ -n "${SSH_CONNECTION:-}" ]; then
            echo "                       SSH session detected, forcing dry-run."
        fi
        return
    fi
    if [ "${1:-}" = "-d" ] || [ "${1:-}" = "--dry-run" ] || [ -n "${SSH_CONNECTION:-}" ]; then
        DRY_RUN="true"
    fi

    if hgit_last_commit_not_yet_pushed; then
        hgit_push
    fi

    TARGET_BRANCH="${2:-$MASTER_BRANCH}"

    CURR_BRANCH="$(hgit_branch)"
    if [ "$CURR_BRANCH" = "$MASTER_BRANCH" ]; then
        echo "Creating a PR from $MASTER_BRANCH is not practical, create a branch first"
        echo "(try: \`hgit branch <some branch name>; hgit push; hgit pr\`)"
        return
    fi

    ORIGIN_URL="$(git remote get-url origin)"
    # See if this even is a GitHub repo at all
    if [ "$(cut -c -15 <<<"$ORIGIN_URL")" != "git@github.com:" ]; then
        echo "Sorry, not a GitHub repo, so I don't know how to do PRs here."
        return
    fi

    ORIGIN_OWNER_AND_REPO="$(cut -c 16- <<<"$ORIGIN_URL")"
    ORIGIN_OWNER="$(cut -d/ -f1 <<<"$ORIGIN_OWNER_AND_REPO")"
    ORIGIN_REPO="$(cut -d/ -f2 <<<"$ORIGIN_OWNER_AND_REPO" | sed 's/.git$//')"

    # Find out which remote the current branch is tracking
    REMOTE="$(hgit_remote_for_branch "$CURR_BRANCH")"
    if [ -z "$REMOTE" ]; then
        echo "Sorry, could not find out which remote the current branch ($CURR_BRANCH) belongs to."
        return
    fi

    if [ "$REMOTE" != "origin" ]; then
        REMOTE_OWNER_AND_REPO="$(git remote get-url "$REMOTE" | cut -c 16-)"
        REMOTE_OWNER="$(cut -d/ -f1 <<<"$REMOTE_OWNER_AND_REPO")"
        COMPARE_TO="$REMOTE_OWNER:$CURR_BRANCH"
    else
        COMPARE_TO="$CURR_BRANCH"
    fi

    URL="https://github.com/${ORIGIN_OWNER}/${ORIGIN_REPO}/compare/${TARGET_BRANCH}...${COMPARE_TO}"

    if [ "$DRY_RUN" = "true" ]; then
        echo "$URL"
    else
        x-www-browser "$URL"
    fi
}

# File ops

function hgit_forget {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Forget about changes we added to the staging area."
        echo
        echo "Usage: hgit forget [-h|--help] <files>"
        return
    fi
    git reset HEAD -- "$@"
}

function hgit_revert {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Revert a file in the workdir to whatever is in the repo."
        echo
        echo "Usage: hgit revert [-h|--help] <files>"
        return
    fi
    git checkout -- "$@"
}

function hgit_re {
    hgit_revert "$@"
}

function hgit_add {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Add files to the staging area, to be picked up by the next commit."
        echo
        echo "Usage: hgit add [-h|--help] [-p|--patch] [-n|--dry-run|--preview] <files>"
        echo
        echo "This is useful when:"
        echo
        echo " * You want to commit a file that the repo doesn't even know about yet."
        echo
        echo " * You have edited a file and only want to commit some parts of the"
        echo "   changes you made. In this case, call \`hgit add -p <your-file>\`,"
        echo "   select the changes, and when you're done, \`hgit commit\` them."
        echo
        echo " * You're about to commit a huge change and want to collect the changes"
        echo "   before committing them in a way that you can check as you go using"
        echo "   \`hgit diff-staging\`."
        echo
        echo "Reverse conclusion:"
        echo
        echo "If none of these apply and you've just made a few changes and want to"
        echo "just get them into the damn repo, you can skip this step and straight"
        echo "away use \`hgit commit\` or \`hgit change\` on that file."
        return
    fi
    if [ "${1:-}" = "-p" ] || [ "${1:-}" = "--patch" ] || [ "${1:-}" = "--partial" ]; then
        shift
        git add -p -- "$@"
    elif [ "${1:-}" = "-n" ] || [ "${1:-}" = "--dry-run" ] || [ "${1:-}" = "--preview" ]; then
        shift
        git add -n -- "$@"
    else
        git add -- "$@"
    fi
}

function hgit_cp {
    if [ -z "${1:-}" ] || [ -z "${2:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Copy a file or directory and add the destination to the repo."
        echo
        echo "Usage: hgit cp <source> <destination>"
        return
    fi
    SOURCE="$1"
    DEST="$2"
    if [ -d "$SOURCE" ]; then
        DASH_R="-r"
    fi
    if [ -d "$DEST" ]; then
        DEST="$DEST/$(basename "$SOURCE")"
    fi
    cp -p ${DASH_R:-} "$SOURCE" "$DEST"
    git add -- "$DEST"
}

function hgit_mv {
    if [ -z "${1:-}" ] || [ -z "${2:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Move or rename a file or directory."
        echo
        echo "Usage: hgit mv [-A|--already] <source> <destination>"
        echo
        echo "Specify -A or --already if you moved it already and now"
        echo "want to record that move in the repo."
        echo
        echo "Unlike \`mv\` or \`git mv\`, supports only a single"
        echo "<source> argument."
        return
    fi
    if [ "${1:-}" = "-A" ] || [ "${1:-}" = "--already" ]; then
        SOURCE="$2"
        DEST="$3"
        # Undo the move first, so that we can then re-do it using "git mv".
        if [ -e "$SOURCE" ]; then
            echo "$SOURCE still exists. Not sure what that means, thus we'll abort."
            return 1
        fi
        if [ -d "$DEST" ]; then
            # $SOURCE now probably exists as "$DEST/$(basename "$SOURCE")".
            MAYBE_DEST="$DEST/$(basename "$SOURCE")"
            if [ -e "$MAYBE_DEST" ]; then
                mv "$MAYBE_DEST" "$SOURCE"
            else
                mv "$DEST" "$SOURCE"
            fi
        else
            mv "$DEST" "$SOURCE"
        fi
    else
        SOURCE="$1"
        DEST="$2"
    fi
    # Let's see if we need to mkdir the target directory first.
    # We will assume the "$DEST" to be a file name, UNLESS
    # * it points to a directory that exists, or
    # * it ends with a `/`.
    if [ -d "$DEST" ] || [[ "$DEST" = */ ]]; then
        # Directory!
        mkdir -p "$DEST"
    else
        # Everything else is assumed to be a file name.
        mkdir -p "$(dirname "$DEST")"
    fi
    # remember if the source arg pointed to a directory
    SOURCE_IS_DIR="$([ -d "$SOURCE" ] && echo true || echo false)"
    # Do the move
    git mv "$SOURCE" "$DEST"
    # If the source directory is now empty, delete it
    RMDIR_TARGET="$SOURCE"
    if [ "$SOURCE_IS_DIR" = false ]; then
        RMDIR_TARGET="$(dirname "$SOURCE")"
    fi
    if [ "$RMDIR_TARGET" != "." ]; then
        rmdir -p --ignore-fail-on-non-empty "$(dirname "$RMDIR_TARGET")"
    fi
}

function hgit_rm {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Delete files from the repo."
        echo
        echo "Usage: hgit rm <path>"
        return
    fi
    if [ -d "$1" ]; then
        DASH_R="-r"
    fi
    git rm ${DASH_R:-} -- "$@"
}

function hgit_ignore {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Add paths to the .gitignore file and commit it."
        echo
        echo "Usage: hgit ignore [-h|--help] <files>"
        echo
        echo "Paths will be added relative to the root directory, no matter how you"
        echo "specify them - don't worry about syntax, just fire away :)"
        return
    fi
    while [ -n "${1:-}" ]; do
        GITIGNORE_EXISTED="$([ -e "$REPO_ROOT/.gitignore" ] && echo true || echo false)"
        IGNORE_PATH="$(realpath --relative-to="$REPO_ROOT" "$1")"
        if [ -d "$1" ]; then
            IGNORE_PATH="${IGNORE_PATH}/"
        fi
        echo "$IGNORE_PATH" >> "$REPO_ROOT/.gitignore"
        if [ "$GITIGNORE_EXISTED" = "false" ]; then
            hgit_add "$REPO_ROOT/.gitignore"
        fi
        hgit_commit "$REPO_ROOT/.gitignore" -m "gitignore $1"
        shift
    done
}

function hgit_cat {
    if [ -z "${1:-}" ]; then
        echo "need args, see --help" >&2
        return
    fi
    COMMIT="HEAD"
    FILES=()
    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "Dump files in a given revision or HEAD from the repo to stdout."
                echo
                echo "Usage: hgit cat [-c <commit ID>] <files>"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -c --commit           Use the given commit rather than HEAD."
                return
                ;;
            -c|--commit)
                COMMIT="$2"
                shift
                ;;
            *)
                FILES+=("$1")
                ;;
        esac
        shift
    done
    ARGS=()
    for FILE in "${FILES[@]}"; do
        ARGS+=("$COMMIT:$FILE")
    done
    git show "${ARGS[@]}"
}

function hgit_touch {
    if [ -z "${1:-}" ] || [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Create or touch a file, creating all its parent directories."
        echo
        echo "Usage: hgit touch <path>"
        return
    fi

    while [ -n "${1:-}" ]; do
        # Let's see if we need to mkdir the target directory first.
        # We will assume "$1" to be a file name, UNLESS
        # * it points to a directory that exists, or
        # * it ends with a `/`.
        if [ -d "$1" ] || [[ "$1" = */ ]]; then
            # Directory!
            mkdir -p "$1"
        else
            # Everything else is assumed to be a file name.
            mkdir -p "$(dirname "$1")"
        fi

        touch "$1"
        shift
    done
}

function hgit_gh {
    if [ -z "${1:-}" ]; then
        echo "need args, see --help" >&2
        return
    fi

    COMMIT="$(git log --format="%H" -n 1)" # last commit in current branch
    DRY_RUN="false"
    REMOTE="$(hgit_remote_for_branch "$(hgit_branch)")"
    FILES=()

    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "View files in a given revision or HEAD on GitHub in your browser."
                echo
                echo "Usage: hgit gh [options] <files>"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -c --commit           Use the given commit rather than HEAD."
                echo " -d --dry-run          Only print the URLs, do not open the browser."
                if [ -n "${SSH_CONNECTION:-}" ]; then
                    echo "                       SSH session detected, forcing dry-run."
                fi
                echo " -o --origin           Always show origin, even if we're on a branch other than $MASTER_BRANCH."
                return
                ;;
            -c|--commit)
                COMMIT="$2"
                shift
                ;;
            -d|--dry-run)
                DRY_RUN="true"
                ;;
            -o|--origin)
                REMOTE="origin"
                ;;
            *)
                FILES+=("$1")
                ;;
        esac
        shift
    done

    if [ -n "${SSH_CONNECTION:-}" ]; then
        DRY_RUN="true"
    fi

    REMOTE_URL="$(git remote get-url "$REMOTE")"
    # See if this even is a GitHub repo at all
    if [ "$(cut -c -15 <<<"$REMOTE_URL")" != "git@github.com:" ]; then
        echo "Sorry, not a GitHub repo, so I don't know how to view files here."
        return
    fi

    REMOTE_OWNER_AND_REPO="$(cut -c 16- <<<"$REMOTE_URL")"
    REMOTE_OWNER="$(cut -d/ -f1 <<<"$REMOTE_OWNER_AND_REPO")"
    REMOTE_REPO="$(cut -d/ -f2 <<<"$REMOTE_OWNER_AND_REPO" | sed 's/.git$//')"

    for FILE in "${FILES[@]}"; do
        URL="https://github.com/${REMOTE_OWNER}/${REMOTE_REPO}/tree/${COMMIT}/${FILE}"
        if [ "$DRY_RUN" = "true" ]; then
            echo "$URL"
        else
            x-www-browser "$URL"
        fi
    done
}


if [ "${RUNNING_IN_CI:-false}" = "false" ]; then
    if [ ! -n "$COMMAND" ]; then
        echo "need a command, see --help"
        exit 1
    fi

    if [ "$(type -t "hgit_$COMMAND")" != "function" ]; then
        echo "command $COMMAND is not defined, see --help"
        exit 1
    fi

    "hgit_$COMMAND" "$@"
fi
