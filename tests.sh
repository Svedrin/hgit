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

function assert_file_empty {
    assert [ "`<"$1" wc -l`" = "0" ]
}

function run_test() {
    FUNC="$1"
    cd "$ROOTDIR"
    rm -f "$TEMPDIR/git-commands.txt"
    echo -n "$FUNC... "
    if $FUNC; then
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
    hgit_init "$TEMPDIR/repo" >/dev/null
    assert grep -q "git init" "$TEMPDIR/git-commands.txt"
    cp "$ROOTDIR/tests/README.md" "$TEMPDIR/repo"

    cd "$TEMPDIR/repo"
    hgit_d  > "$TEMPDIR/d.txt"
    assert_file_empty "$TEMPDIR/d.txt"
    hgit_st > "$TEMPDIR/st.txt"
    assert diff "$TEMPDIR/st.txt" "$ROOTDIR/tests/hgit_basic_st_before_add.txt"
    assert grep -q "git status" "$TEMPDIR/git-commands.txt"

    hgit_add README.md
    hgit_st > "$TEMPDIR/st.txt"
    assert diff "$TEMPDIR/st.txt" "$ROOTDIR/tests/hgit_basic_st_after_add.txt"
    assert grep -q "git add" "$TEMPDIR/git-commands.txt"

    hgit_d > "$TEMPDIR/d.txt"
    assert_file_empty "$TEMPDIR/d.txt"

    hgit_dc > "$TEMPDIR/dc.txt"
    assert diff "$TEMPDIR/dc.txt" "$ROOTDIR/tests/hgit_basic_dc_after_add.txt"

    hgit_ci README.md -m "initial import" > "$TEMPDIR/ci.txt"
    assert grep -q "root-commit" "$TEMPDIR/ci.txt"
    assert grep -q "git commit" "$TEMPDIR/git-commands.txt"

    hgit_br 0-feature-branch 2> "$TEMPDIR/br.txt"
    assert [ "`hgit_branch`" = "0-feature-branch" ]
    assert grep -q "git checkout -b 0-feature-branch" "$TEMPDIR/git-commands.txt"

    echo "some more content" >> README.md
    hgit_st > "$TEMPDIR/st.txt"
    assert diff "$TEMPDIR/st.txt" "$ROOTDIR/tests/hgit_basic_st_after_modify.txt"

    hgit_d > "$TEMPDIR/d.txt"
    assert diff "$TEMPDIR/d.txt" "$ROOTDIR/tests/hgit_basic_d_after_modify.txt"

    hgit_dc > "$TEMPDIR/dc.txt"
    assert_file_empty "$TEMPDIR/dc.txt"

    hgit_add README.md

    hgit_d > "$TEMPDIR/d.txt"
    assert_file_empty "$TEMPDIR/d.txt"

    hgit_dc > "$TEMPDIR/dc.txt"
    assert diff "$TEMPDIR/dc.txt" "$ROOTDIR/tests/hgit_basic_d_after_modify.txt"

    hgit_ci README.md -m "modify stuff" > "$TEMPDIR/ci.txt"
    assert grep -q "0-feature-branch" "$TEMPDIR/ci.txt"
}

run_test test_hgit_basic_workflow
