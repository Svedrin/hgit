#!/bin/bash

set -e
set -u

# Create a temp dir to do our work in.

ROOTDIR="$PWD"
TEMPDIR="$(mktemp -d)"

function cleanup() {
    rm -rf "$TEMPDIR"
}

trap cleanup exit

# Define helper functions.

function assert() {
    if ! "$@"; then
        echo "Assertion failed:" "$@"
        return 1
    fi
}

function assert_fails() {
    if "$@"; then
        echo "Assertion failed, expected failure:" "$@"
        return 1
    fi
}

function assert_file_empty {
    assert [ "`<"$1" wc -l`" = "0" ]
}

function run_test() {
    FUNC="$1"
    cd "$ROOTDIR"
    rm -f "$TEMPDIR/git-commands.txt"
    echo -n "$FUNC... "
    # Run in a subshell with errexit, so that the first failed assertion
    # fails the test (errexit would be ignored inside of an `if`).
    set +e
    ( set -e; $FUNC )
    RC=$?
    set -e
    if [ "$RC" = "0" ]; then
        echo "ok"
    else
        echo "failed"
        exit 1
    fi
}

# Catch `git` commands executed by hgit.

function run_git {
    "`which git`" "$@" >/dev/null 2>&1
}

function git {
    echo "git $@" >> "$TEMPDIR/git-commands.txt"
    "`which git`" "$@"
}

# Define basic variables for hgit

RUNNING_IN_CI=true
MY_GITHUB_USER="TheoTheTester"
REPO_ROOT="$TEMPDIR/repo"
MASTER_BRANCH="master"

export LANG=C

source hgit.sh

# Here come the tests!

function test_hgit_basic_workflow() {
    # Initialize an empty repo and copy README.md into it.
    hgit_init "$TEMPDIR/repo" >/dev/null
    assert grep -q "git init" "$TEMPDIR/git-commands.txt"
    cp "$ROOTDIR/tests/README.md" "$TEMPDIR/repo"
    cd "$TEMPDIR/repo"

    if [ -e ".git/hgitrc" ]; then
        . ".git/hgitrc"
    fi

    # diff the readme while it is still an unknown file.
    hgit_d  > "$TEMPDIR/d.txt"
    assert_file_empty "$TEMPDIR/d.txt"
    # Run h st while the readme is still an unknown file.
    hgit_st > "$TEMPDIR/st.txt"
    assert diff "$TEMPDIR/st.txt" "$ROOTDIR/tests/hgit_basic_st_before_add.txt"
    assert grep -q "git status" "$TEMPDIR/git-commands.txt"

    # Add the readme to the staging area, run both diff variants and st again.
    hgit_add README.md
    hgit_st > "$TEMPDIR/st.txt"
    assert diff "$TEMPDIR/st.txt" "$ROOTDIR/tests/hgit_basic_st_after_add.txt"
    assert grep -q "git add" "$TEMPDIR/git-commands.txt"

    hgit_d > "$TEMPDIR/d.txt"
    assert_file_empty "$TEMPDIR/d.txt"

    hgit_dc > "$TEMPDIR/dc.txt"
    assert diff "$TEMPDIR/dc.txt" "$ROOTDIR/tests/hgit_basic_dc_after_add.txt"

    # Commit the readme.
    hgit_ci README.md -m "initial import" > "$TEMPDIR/ci.txt"
    assert grep -q "root-commit" "$TEMPDIR/ci.txt"
    assert grep -q "git commit" "$TEMPDIR/git-commands.txt"

    # Create a feature branch.
    hgit_br 0-feature-branch 2> "$TEMPDIR/br.txt"
    assert [ "`hgit_branch`" = "0-feature-branch" ]
    assert grep -q "git checkout -b 0-feature-branch" "$TEMPDIR/git-commands.txt"

    # Add some content to the readme, run st and both variants of diff again.
    echo "some more content" >> README.md
    hgit_st > "$TEMPDIR/st.txt"
    assert diff "$TEMPDIR/st.txt" "$ROOTDIR/tests/hgit_basic_st_after_modify.txt"

    # Workdir-diff has modifications
    hgit_d > "$TEMPDIR/d.txt"
    assert diff "$TEMPDIR/d.txt" "$ROOTDIR/tests/hgit_basic_d_after_modify.txt"

    # Staging-diff is clean
    hgit_dc > "$TEMPDIR/dc.txt"
    assert_file_empty "$TEMPDIR/dc.txt"

    # Add the readme to the staging area
    hgit_add README.md

    # Workdir-diff is now clean
    hgit_d > "$TEMPDIR/d.txt"
    assert_file_empty "$TEMPDIR/d.txt"

    # Staging-diff now has modifications
    hgit_dc > "$TEMPDIR/dc.txt"
    assert diff "$TEMPDIR/dc.txt" "$ROOTDIR/tests/hgit_basic_d_after_modify.txt"

    # Try a commit while giving the name on command line (this must fail)
    hgit_ci README.md -m "modify stuff" > "$TEMPDIR/ci-fail.txt"
    assert grep -q "aborting" "$TEMPDIR/ci-fail.txt"

    # Try a commit without any file names (this must work)
    hgit_ci -m "modify stuff" > "$TEMPDIR/ci.txt"
    assert grep -q "0-feature-branch" "$TEMPDIR/ci.txt"

    # Switch back to main
    hgit_use main >/dev/null 2>&1
    assert [ "`hgit_branch`" = "main" ]
}

# Set up a repo with a few tracked files in nested directories, and cd into it.
function mv_test_repo() {
    rm -rf "$TEMPDIR/mv"
    mkdir "$TEMPDIR/mv"
    cd "$TEMPDIR/mv"
    run_git init .
    mkdir -p a/b/c x
    echo 1 > a/b/c/f.txt
    echo 2 > a/b/g.txt
    echo 3 > a/h.txt
    echo 4 > x/y.txt
    run_git add -A
}

function assert_exists {
    assert [ -e "$1" ]
}

function assert_gone {
    assert [ ! -e "$1" ]
}

function assert_staged {
    assert grep -q -- "$1" <(git status --porcelain)
}

function test_hgit_mv_file_prunes_empty_dirs() {
    mv_test_repo
    hgit_mv a/b/c/f.txt n/o/p/f.txt
    assert_exists n/o/p/f.txt
    # a/b/c is empty now, a/b is not (g.txt).
    assert_gone a/b/c
    assert_exists a/b/g.txt
    assert_staged "f.txt"

    # Moving the rest of a/b away takes a/b with it, but not a (h.txt).
    hgit_mv a/b/g.txt n/g.txt
    assert_gone a/b
    assert_exists a/h.txt

    # And a goes, too, once it's empty.
    hgit_mv a/h.txt h.txt
    assert_gone a
}

function test_hgit_mv_into_dir() {
    mv_test_repo
    hgit_mv a/h.txt x
    assert_exists x/h.txt
    hgit_mv a/b/g.txt new/
    assert_exists new/g.txt
    assert_exists a/b/c/f.txt
}

function test_hgit_mv_dir() {
    mv_test_repo
    # Trailing slash on the source, as left by tab completion.
    hgit_mv a/b/c/ deep/er/c
    assert_exists deep/er/c/f.txt
    assert_gone a/b/c
    assert_exists a/b/g.txt

    # Rename a directory into an existing one.
    hgit_mv a/b x
    assert_exists x/b/g.txt
    assert_gone a/b
    assert_exists a/h.txt
}

function test_hgit_mv_keeps_dirs_with_untracked_files() {
    mv_test_repo
    echo junk > a/b/c/untracked.txt
    hgit_mv a/b/c/f.txt n/f.txt
    assert_exists a/b/c/untracked.txt
    assert_exists n/f.txt
}

function test_hgit_mv_failure_leaves_no_trace() {
    mv_test_repo
    echo untracked > u.txt
    # Source doesn't exist, isn't tracked, or the destination is taken.
    assert_fails hgit_mv nope new/dir/f.txt 2>/dev/null
    assert_fails hgit_mv u.txt new/dir/u.txt 2>/dev/null
    assert_fails hgit_mv a/h.txt x/y.txt 2>/dev/null
    # Can't move a directory into itself.
    assert_fails hgit_mv a a/new/dir/a 2>/dev/null
    assert_gone new
    assert_gone a/new
    assert_exists a/h.txt
    assert_exists u.txt
    assert_exists x/y.txt
}

function test_hgit_mv_from_subdir_and_outside() {
    mv_test_repo
    # Moving out of the directory we're in must not stray above the repo.
    cd a/b/c
    hgit_mv f.txt ../../../n/f.txt
    cd "$TEMPDIR/mv"
    assert_exists n/f.txt
    assert_gone a/b/c
    assert_exists a/b/g.txt
    # The repo root itself is never removed, even when it's the only thing left.
    assert_exists "$TEMPDIR/mv/.git"
}

function test_hgit_mv_already() {
    mv_test_repo
    # File renamed to a new name.
    mkdir -p n && mv a/h.txt n/h2.txt
    hgit_mv -A a/h.txt n/h2.txt
    assert_exists n/h2.txt
    assert_staged "h2.txt"

    # File moved into an existing directory.
    mv a/b/g.txt x/
    hgit_mv -A a/b/g.txt x
    assert_exists x/g.txt
    assert_gone a/b/g.txt

    # Directory moved into an existing directory.
    mv a/b/c x/
    hgit_mv -A a/b/c x
    assert_exists x/c/f.txt
    assert_gone a
}

function test_hgit_mv_already_dir_renamed_over_samename_child() {
    mv_test_repo
    mkdir -p d/d
    echo 5 > d/d/z.txt
    run_git add -A
    mv d e
    hgit_mv -A d e
    assert_exists e/d/z.txt
    assert_gone d

    # Same again, with the trailing slash that tab completion leaves behind.
    mv e d
    run_git add -A
    mv d e
    hgit_mv -A d/ e
    assert_exists e/d/z.txt
    assert_gone d
}

function test_hgit_mv_already_failure_restores_workdir() {
    mv_test_repo
    echo untracked > u.txt
    mv u.txt x/u.txt
    assert_fails hgit_mv -A u.txt x/u.txt 2>/dev/null
    assert_exists x/u.txt
    assert_gone u.txt
    # Source still there.
    assert_fails hgit_mv -A a/h.txt x/y.txt 2>/dev/null
    assert_exists x/y.txt
}

# Set up a repo with one commit and some uncommitted work in it, and cd into it.
function secondscreen_test_repo() {
    rm -rf "$TEMPDIR/2nd" "$TEMPDIR/2nd-2nd-side"*
    mkdir "$TEMPDIR/2nd"
    cd "$TEMPDIR/2nd"
    run_git init .
    echo 1 > f.txt
    echo 1 > g.txt
    run_git add -A
    run_git commit -m init
    # Uncommitted work: one modified, one staged, one untracked file.
    echo wip > g.txt
    echo new > staged.txt
    run_git add staged.txt
    echo untracked > u.txt
}

function assert_no_branch {
    assert_fails "`which git`" rev-parse --verify --quiet "refs/heads/$1" >/dev/null
}

function test_hgit_2nd_merges_back() {
    secondscreen_test_repo
    printf 'echo side > side.txt\ngit add side.txt\ngit commit -qm side\nexit\n' \
        | hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    # The side task is merged into our branch, and cleaned up.
    assert_exists side.txt
    assert_gone "$TEMPDIR/2nd-2nd-side"
    assert_no_branch side
    assert [ "`hgit_branch`" = "master" ]
    # Our uncommitted work is untouched.
    assert [ "`cat g.txt`" = "wip" ]
    assert_staged "A  staged.txt"
    assert_exists u.txt
}

function test_hgit_2nd_default_name() {
    secondscreen_test_repo
    printf 'echo side > side.txt\ngit add side.txt\ngit commit -qm side\nexit\n' \
        | hgit_2nd > "$TEMPDIR/2nd.txt" 2>&1
    assert_exists side.txt
    assert_no_branch 2nd-master
}

function test_hgit_2nd_starts_clean() {
    secondscreen_test_repo
    # None of our uncommitted work shows up in the second screen. Nothing to
    # commit there, so merging is a no-op.
    printf 'test ! -e u.txt && test ! -e staged.txt && test "$(cat g.txt)" = 1\nexit\n' \
        | hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    assert_gone "$TEMPDIR/2nd-2nd-side"
    assert_no_branch side
}

function test_hgit_2nd_dirty_worktree_goes_back_to_shell() {
    secondscreen_test_repo
    # First session leaves an untracked file behind, second one removes it again.
    printf 'echo junk > junk.txt\nexit\nrm junk.txt\necho side > side.txt\ngit add side.txt\ngit commit -qm side\nexit\n' \
        | hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    assert grep -q "not clean" "$TEMPDIR/2nd.txt"
    assert grep -q -- "?? junk.txt" "$TEMPDIR/2nd.txt"
    assert_exists side.txt
    assert_no_branch side
}

function test_hgit_2nd_wip_conflicting_with_merge_leaves_markers() {
    secondscreen_test_repo
    # The side task touches a file we have uncommitted changes in. The merge
    # itself works, so everything is cleaned up, but our changes are left
    # with conflict markers and the stash entry is kept.
    printf 'echo side > g.txt\ngit commit -qam side\nexit\n' \
        | hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    assert grep -q "conflict" "$TEMPDIR/2nd.txt"
    assert grep -q "<<<<<<<" g.txt
    assert grep -q "wip" g.txt
    assert grep -q "side" g.txt
    assert [ "`git stash list | wc -l`" = "1" ]
    assert_gone "$TEMPDIR/2nd-2nd-side"
    assert_no_branch side
}

function test_hgit_2nd_keeps_worktree_if_merge_fails() {
    secondscreen_test_repo
    # Our branch moves on while we're in the second screen, and the two
    # changes conflict.
    printf 'echo side > f.txt\ngit commit -qam side\necho main > "%s/f.txt"\ngit -C "%s" commit -qm main -- f.txt\nexit\n' \
        "$TEMPDIR/2nd" "$TEMPDIR/2nd" \
        | assert_fails hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    assert grep -q "failed" "$TEMPDIR/2nd.txt"
    assert grep -q "git stash pop" "$TEMPDIR/2nd.txt"
    assert_exists "$TEMPDIR/2nd-2nd-side"
    assert "`which git`" rev-parse --verify --quiet refs/heads/side >/dev/null
    assert grep -q "<<<<<<<" f.txt
    # The merge blocks popping our changes, they wait in the stash.
    assert [ "`git stash list | wc -l`" = "1" ]

    # Resolve the merge, get our changes back and retry, which resumes the
    # worktree and cleans up.
    echo resolved > f.txt
    run_git commit -am "merge side"
    run_git stash pop
    printf 'exit\n' | hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    assert grep -q "resuming" "$TEMPDIR/2nd.txt"
    assert [ "`cat f.txt`" = "resolved" ]
    assert [ "`cat g.txt`" = "wip" ]
    assert_gone "$TEMPDIR/2nd-2nd-side"
    assert_no_branch side
}

function test_hgit_2nd_keeps_worktree_if_merge_is_refused() {
    secondscreen_test_repo
    # Nothing but staged changes: hgit_with_stash finds nothing modified to
    # stash. Our branch moves on while we're in the second screen, so the merge
    # is not a fast-forward, and git refuses to do it with staged changes around.
    run_git checkout g.txt
    printf 'echo side > side.txt\ngit add side.txt\ngit commit -qm side\necho main > "%s/f.txt"\ngit -C "%s" commit -qm main -- f.txt\nexit\n' \
        "$TEMPDIR/2nd" "$TEMPDIR/2nd" \
        | assert_fails hgit_2nd side > "$TEMPDIR/2nd.txt" 2>&1
    assert_exists "$TEMPDIR/2nd-2nd-side"
    assert "`which git`" rev-parse --verify --quiet refs/heads/side >/dev/null
    # Our uncommitted changes are back where they were.
    assert [ "`cat g.txt`" = "1" ]
    assert_staged "A  staged.txt"
    assert [ "`git stash list | wc -l`" = "0" ]
}

function test_hgit_2nd_refuses_current_branch_and_detached_head() {
    secondscreen_test_repo
    assert_fails hgit_2nd master 2>/dev/null
    run_git checkout --detach
    assert_fails hgit_2nd side 2>/dev/null
    assert_gone "$TEMPDIR/2nd-2nd-side"
}

run_test test_hgit_basic_workflow
run_test test_hgit_mv_file_prunes_empty_dirs
run_test test_hgit_mv_into_dir
run_test test_hgit_mv_dir
run_test test_hgit_mv_keeps_dirs_with_untracked_files
run_test test_hgit_mv_failure_leaves_no_trace
run_test test_hgit_mv_from_subdir_and_outside
run_test test_hgit_mv_already
run_test test_hgit_mv_already_dir_renamed_over_samename_child
run_test test_hgit_mv_already_failure_restores_workdir
run_test test_hgit_2nd_merges_back
run_test test_hgit_2nd_default_name
run_test test_hgit_2nd_starts_clean
run_test test_hgit_2nd_dirty_worktree_goes_back_to_shell
run_test test_hgit_2nd_wip_conflicting_with_merge_leaves_markers
run_test test_hgit_2nd_keeps_worktree_if_merge_fails
run_test test_hgit_2nd_keeps_worktree_if_merge_is_refused
run_test test_hgit_2nd_refuses_current_branch_and_detached_head
