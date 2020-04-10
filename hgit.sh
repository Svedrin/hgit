#!/bin/bash

set -e
set -u

if [ ! -f ~/.hgitrc ]; then
    echo "Please create ~/.hgitrc to configure your GitHub username:"
    echo 'echo MY_GITHUB_USER="your username here" > ~/.hgitrc"'
    exit 2
fi

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
            echo  " clone                 Clone a remote repo, plus your fork if you have one."
            echo  " gh-create             Create a new repo in GitHub and run '$0 gh-fork' on it."
            echo  " gh-fork               Clone a remote repo, plus create a fork if you do NOT have one."
            echo  " branch, b             Create a new branch."
            echo  " branches              List existing branches."
            echo  " use                   Switch to an existing branch, even if it only exists in your"
            echo  "                       fork but not yet locally."
            echo
            echo  " diff, d               Diff workdir."
            echo  " cachediff, dc         Diff staging area."
            echo  " commit, ci            Commit."
            echo  " change, c             Diff-or-commit (see its --help)."
            echo  " log                   Show logs."
            echo  " tag                   Create a tag and push it upstream."
            echo  " amend                 Amend stuff to the last commit, unless you pushed it already."
            echo  " push                  Push changes to a fork or upstream."
            echo  " pull                  Pull changes from a fork or upstream."
            echo  " gh-pr, pr             Open a Pull Request."
            echo
            echo  " add                   Add a file to the repo, or add its changes to the staging area."
            echo  " cp                    Copy src to dest, then add dest to git."
            echo  " mv                    Move or rename a file, or record that you did that already."
            echo  " rm                    Remove a file."
            echo  " cat                   Dump files from the repo to stdout."
            echo  " forget                Un-add/cp/mv/rm a file without touching the workdir."
            echo  " revert, re            Undo your changes and set the file to the latest state in the"
            echo  "                       repo or staging area."
            echo  " ignore                Add a path to .gitignore."
            echo  " gh-view               View a file on GitHub."
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

# Helper functions

function hgit_my_fork () {
    echo "${MY_GITHUB_USER,,}"
}

function hgit_have_remote () {
    git remote | grep -q "^$1$"
}

function hgit_have_fork () {
    hgit_have_remote "$(hgit_my_fork)"
}

function hgit_remote_for_branch () {
    BRANCH="$1"
    git branch --format='%(refname:short) %(upstream:remotename)' | while read branch remote; do
        if [ "$branch" = "$BRANCH" ] && [ -n "$remote" ]; then
            echo "$remote"
            break
        fi
    done
}

# Init, clone

function hgit_init () {
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

function hgit_clone () {
    if [ -z "${1:-}" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Clone an existing repo, and if it's from GitHub and you"
        echo "have a fork, clone that too."
        echo
        echo "Usage: hgit clone [-h|--help] git@github.com:<owner>/<repo>.git [<target dir>]"
        echo
        echo "The magic that checks out your fork only works with GitHub and only"
        echo "with SSH URLs. Other URLs are checked out as well, but they are"
        echo "passed on to git as they are without trying to do anything clever."
        return
    fi

    URL="$1"

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
    INTO="${2:-$REPO}"

    git clone "$1" "$INTO"

    if [ "$OWNER" = "$MY_GITHUB_USER" ]; then
        return
    fi

    MY_REMOTE_URL="git@github.com:$(hgit_my_fork)/${REPO}.git"
    if git ls-remote --heads "$MY_REMOTE_URL" &>/dev/null; then
        cd "$INTO"
        git remote add "$(hgit_my_fork)" "$MY_REMOTE_URL"
        git fetch "$(hgit_my_fork)"
    fi
}


# Status

function hgit_status () {
    git status "$@"
}

function hgit_st () {
    git status --short --branch "$@"
}

# Diff

function hgit_diff {
    COMMIT=""
    FILES=()
    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "View differences of a file vs the one in the repo."
                echo
                echo "Usage: hgit diff [-c <commit ID>] [files]"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -c --commit           Show changes made in a certain commit."
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
        git diff --no-prefix "$COMMIT^" "$COMMIT" -- "${FILES[@]}"
    else
        git diff --no-prefix -- "${FILES[@]}"
    fi
}

function hgit_d {
    hgit_diff "$@"
}

function hgit_cachediff {
    git diff --no-prefix --cached -- "$@"
}

function hgit_dc {
    hgit_cachediff "$@"
}

# Commit

function hgit_commit {
    git commit "$@"
}

function hgit_ci {
    hgit_commit "$@"
}

function hgit_change () {
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
        hgit_cachediff "${FILES[@]}"
        hgit_diff "${FILES[@]}"
    fi
}

function hgit_c {
    hgit_change "$@"
}

# Branches

function hgit_branches {
    git branch -l
}

function hgit_use () {
    if [ -z "${1:-}" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo "Find and switch to an existing branch."
        echo
        echo "Usage: hgit use [-h|--help] [<remote>] <search term>"
        echo
        echo "If switching to 'master' and a fork exists, an implicit"
        echo "sync is performed to remove local branches that have been"
        echo "deleted in the fork (e.g. after a PR is merged)."
        return
    fi
    if [ "$1" = "master" ] && [ -z "${2:-}" ]; then
        git checkout master
        # If we have a fork of this repo, prune branches that no longer exist in it
        if hgit_have_fork; then
            git fetch -p $(hgit_my_fork)
        fi
        return
    elif [ -z "${2:-}" ]; then
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
    # Try to find the branch locally.
    CANDIDATES=($(git branch -l | cut -c3- | grep "$SEARCH" || true))
    if [ "${#CANDIDATES[*]}" = "1" ]; then
        git checkout "${CANDIDATES[0]}"
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
        git branch --show-current
    elif git branch -l | cut -c3- | grep -q "^$1$"; then
        # Branch exists already, switch to it
        hgit_use "$1"
    else
        # Branch does not exist, create it
        git checkout -b "$1"
    fi
}

function hgit_b {
    hgit_branch "$@"
}


# Push/pull

function hgit_pull {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Pull changes from a remote."
        echo
        echo "Usage: hgit pull [-h|--help] [<remote> [<branch>]|master]"
        echo
        echo "If remote and branch are both specified, we'll pull that branch from that remote."
        echo "If just a remote is given, we'll pull the current branch from that remote."
        echo "If just the word 'master' is given, we'll pull origin master."
        echo "If nothing is given and we're on master, we'll pull origin master."
        echo "If nothing is given and we're not on master and we have a fork, we'll pull the current branch from there."
        echo "If nothing is given and we're not on master and we do not have a fork, we'll pull the current branch from origin."
        return
    fi
    CURR_BRANCH="$(hgit_branch)"
    # How many args do we have?
    if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then
        # Two args: remote and branch
        REMOTE="$1"
        BRANCH="$2"
    elif [ "${1:-}" = "master" ]; then
        # One arg == "master"
        REMOTE="origin"
        BRANCH="master"
    elif [ -n "${1:-}" ]; then
        # One arg: Remote
        REMOTE="$1"
        BRANCH="$CURR_BRANCH"
    elif [ "$CURR_BRANCH" = "master" ]; then
        # One arg == "master"
        REMOTE="origin"
        BRANCH="master"
    elif hgit_have_fork; then
        # No args, and we have a fork
        REMOTE="$(hgit_my_fork)"
        BRANCH="$CURR_BRANCH"
    else
        # No args, no fork
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
        echo "If remote is not specified and we're on master, we'll push to origin master."
        echo "If remote is not specified and we're not on master and we have a fork, we'll push to the fork."
        echo "If remote is not specified and we're not on master and we do not have a fork, we'll push to origin."
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
    elif [ "$CURR_BRANCH" = "master" ]; then
        git push $SET_UPSTREAM "origin" "master"
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

function hgit_gh_pr {
    DRY_RUN="false"
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        echo "Open the web browser to create a GitHub PR from the current branch."
        echo
        echo "Usage: hgit pr [-h|--help|-d|--dry-run] [<target branch>]"
        echo
        echo "Target branch defaults to master."
        echo
        echo "Options:"
        echo " -h --help             This help text"
        echo " -d --dry-run          Only print the URL, do not open the browser."
        return
    fi
    if [ "${1:-}" = "-d" ] || [ "${1:-}" = "--dry-run" ]; then
        DRY_RUN="true"
    fi

    TARGET_BRANCH="${2:-master}"

    CURR_BRANCH="$(hgit_branch)"
    if [ "$CURR_BRANCH" = "master" ]; then
        echo "Creating a PR from master is not practical, create a branch first"
        echo "(try: hgit branch <some branch name>; hgit push; hgit pr)"
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
        COMPARE_TO="$CURRENT_BRANCH"
    fi

    URL="https://github.com/${ORIGIN_OWNER}/${ORIGIN_REPO}/compare/${TARGET_BRANCH}...${COMPARE_TO}"

    if [ "$DRY_RUN" = "true" ]; then
        echo "$URL"
    else
        x-www-browser "$URL"
    fi
}

function hgit_pr {
    hgit_gh_pr "$@"
}

# File ops

function hgit_forget {
    git reset HEAD -- "$@"
}

function hgit_revert {
    git checkout -- "$@"
}

function hgit_re {
    hgit_revert "$@"
}

function hgit_add {
    git add -- "$@"
}

function hgit_rm {
    git rm -- "$@"
}

function hgit_ignore {
    REPO_ROOT="$(git rev-parse --show-toplevel)"
    while [ -n "${1:-}" ]; do
        IGNORE_PATH="$(realpath --relative-to="$REPO_ROOT" "$1")"
        if [ -d "$1" ]; then
            IGNORE_PATH="${IGNORE_PATH}/"
        fi
        echo "$IGNORE_PATH" >> "$REPO_ROOT/.gitignore"
        hgit_commit "$REPO_ROOT/.gitignore" -m "gitignore $1"
        shift
    done
}

function hgit_cat () {
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

function hgit_gh_view {
    if [ -z "${1:-}" ]; then
        echo "need args, see --help" >&2
        return
    fi

    COMMIT="HEAD"
    DRY_RUN="false"
    REMOTE="$(hgit_remote_for_branch "$(hgit_branch)")"
    FILES=()

    while [ -n "${1:-}" ]; do
        case "$1" in
            -h|--help)
                echo "Dump files in a given revision or HEAD from the repo to stdout."
                echo
                echo "Usage: hgit cat [options] <files>"
                echo
                echo "Options:"
                echo " -h --help             This help text"
                echo " -c --commit           Use the given commit rather than HEAD."
                echo " -d --dry-run          Only print the URLs, do not open the browser."
                echo " -o --origin           Always show origin, even if we're on a branch other than master."
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




if [ ! -n "$COMMAND" ]; then
    echo "need a command, see --help"
    exit 1
fi

if [ "$(type -t "hgit_$COMMAND")" != "function" ]; then
    echo "command $COMMAND is not defined, see --help"
    exit 1
fi

"hgit_$COMMAND" "$@"
