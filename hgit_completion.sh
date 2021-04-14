_hgit_complete_changed_or_unknown_files () {
    compgen -W "$(git status --short --porcelain | cut -c 4-)" -- "${COMP_WORDS[-1]}"
}

_hgit_complete_branches () {
    if [ "${#COMP_WORDS[@]}" -gt 1 ]; then
        git branch -l | grep -- "${COMP_WORDS[-1]}"
    else
        git branch -l
    fi
}

_hgit_complete_bs () {
    _hgit_complete_branches
}

_hgit_complete_use () {
    _hgit_complete_branches
}

_hgit_completions()
{
    # Do we have a command?
    if [ -n "${COMP_WORDS[1]:-}" ]; then
        COMMAND="${COMP_WORDS[1]}"
        # Check if we can complete this command
        # otherwise fallback to normal bash completion
        if [ "$(type -t "_hgit_complete_$COMMAND")" = "function" ]; then
            COMPREPLY=($("_hgit_complete_$COMMAND"))
        else
            for CANDIDATE in status st diff d diff-staging ds dc commit ci change c add forget revert re; do
                if [ "$COMMAND" = "$CANDIDATE" ]; then
                    COMPREPLY=($(_hgit_complete_changed_or_unknown_files))
                fi
            done
        fi
    else
        # Nope, complete with a list of commands
        ALL_COMMANDS="status st diff d diff-staging ds dc commit ci change c add cp mv rm cat forget revert re ignore gh branches bs use"
        COMPREPLY=($(compgen -W "$ALL_COMMANDS" -- "${COMP_WORDS[1]}"))
    fi
}

complete -F _hgit_completions -o default hgit h
