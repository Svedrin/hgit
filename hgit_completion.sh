_hgit_complete_changed_or_unknown_files () {
    compgen -W "$(git -C "$HGIT_COMPLETE_BASEDIR" status --short | cut -c 4-)" -- "${COMP_WORDS[COMP_CWORD]}"
}

# Branch names, one per line. Deliberately not "git branch -l": its "* " and
# "+ " markers would end up in COMPREPLY, and the "*" gets glob-expanded.
# Like hgit use, this matches the typed text anywhere in the name, not just as
# a prefix.
_hgit_complete_branches () {
    git -C "$HGIT_COMPLETE_BASEDIR" for-each-ref --format='%(refname:short)' refs/heads \
        | grep -F -- "${COMP_WORDS[COMP_CWORD]}"
}

_hgit_complete_tags () {
    git -C "$HGIT_COMPLETE_BASEDIR" tag -l "${COMP_WORDS[COMP_CWORD]}*"
}

_hgit_complete_bs () {
    _hgit_complete_branches
}

_hgit_complete_use () {
    _hgit_complete_branches
}

_hgit_complete_join () {
    _hgit_complete_branches
}

_hgit_complete_kill () {
    _hgit_complete_branches
}

# hgit branch-from <new branch name> <commit or tag>
# The first argument is a name that doesn't exist yet, so only complete the second.
_hgit_complete_branch_from () {
    if [ "$COMP_CWORD" -eq $((HGIT_COMPLETE_CMDIDX + 2)) ]; then
        _hgit_complete_tags
        _hgit_complete_branches
    fi
}

_hgit_completions()
{
    COMPREPLY=()

    # Do we have a subdir?
    HGIT_COMPLETE_BASEDIR="$PWD"
    HGIT_COMPLETE_CMDIDX=1
    if [[ "${COMP_WORDS[1]:-}" == */ ]]; then
        HGIT_COMPLETE_BASEDIR="${COMP_WORDS[1]}"
        HGIT_COMPLETE_CMDIDX=2
    fi

    if [ "$COMP_CWORD" -lt "$HGIT_COMPLETE_CMDIDX" ]; then
        # Still typing the subdir, leave that to the default completion.
        return
    elif [ "$COMP_CWORD" -eq "$HGIT_COMPLETE_CMDIDX" ]; then
        # Typing the command itself, complete it from the list of commands.
        ALL_COMMANDS="
            status st init clone collab-with forked
            branch b br branch-from branches bs use kill agent join secondscreen 2nd
            diff d diff-staging dc commit ci uncommit undo backout change c
            log tag tags amend incoming inc outgoing out push pull pr
            add cp mv rm cat touch forget revert re ignore gh drone-sign ds drone
        "
        COMPREPLY=($(compgen -W "$ALL_COMMANDS" -- "${COMP_WORDS[COMP_CWORD]}"))
        return
    fi

    # Typing an argument. Check if we can complete this command
    # otherwise fallback to normal bash completion
    COMMAND="${COMP_WORDS[HGIT_COMPLETE_CMDIDX]}"
    COMPLETER="_hgit_complete_${COMMAND//-/_}"
    if [ "$(type -t "$COMPLETER")" = "function" ]; then
        COMPREPLY=($("$COMPLETER"))
    else
        for CANDIDATE in status st diff d diff-staging dc commit ci change c add forget revert re; do
            if [ "$COMMAND" = "$CANDIDATE" ]; then
                COMPREPLY=($(_hgit_complete_changed_or_unknown_files))
            fi
        done
    fi
}

complete -F _hgit_completions -o default hgit h
