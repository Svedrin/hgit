# hgit - Git for Humans

Opinionated micro-porcelain for git. Assumes that you're working with GitHub, but tries not to fail too badly in case you don't.

Intended Audience: Developers who use Git on the CLI rather than through a GUI or their editor, and have their repos hosted on GitHub.

# How to work with hgit

This section demonstrates hgit in action.

The rest of this document will assume that you have installed `hgit` and aliased it so that you can invoke it by typing just `h`.

## Your repo, no PRs

Suppose you have a repo that you want to work on, and you're working on it alone, pushing changes directly to `master`.

First, clone it:

```
# h clone gh:Svedrin/hgit
Cloning into 'hgit'...
remote: Enumerating objects: 224, done.
remote: Counting objects: 100% (224/224), done.
remote: Compressing objects: 100% (158/158), done.
remote: Total 224 (delta 74), reused 216 (delta 66), pack-reused 0
Receiving objects: 100% (224/224), 42.20 KiB | 258.00 KiB/s, done.
Resolving deltas: 100% (74/74), done.
```

Now make some changes. As an example, I've added a line to `README.md`.

Inspect which files have changed using `h st`:

```
# h st
## master...origin/master
 M README.md
```

See the diff using `h d`:

    # h d
    diff --git README.md README.md
    index d837090..a48fdc3 100644
    --- README.md
    +++ README.md
    @@ -123,3 +123,5 @@ Then:
    ```
    MY_GITHUB_USER="Svedrin"
    ```
    +
    +Hello! I'm changing the README

Commit changes using `h ci`:

```
# h ci README.md -m "some changes"
[master a4559a2] some changes
 1 file changed, 2 insertions(+)
```

Push the change to GitHub:

```
# h push
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 375 bytes | 375.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
To github.com:Svedrin/hgit.git
   478e94b..6f5cb68  master -> master
```

Good to go!

## Your repo, with PRs

Let's make it a bit more complex: What if you want to develop a more complex feature, so you'd like to put commits in a separate branch and create a PR for it? Here's how.

Again, start by cloning the repo:

```
# h clone gh:Svedrin/hgit
Cloning into 'hgit'...
remote: Enumerating objects: 224, done.
remote: Counting objects: 100% (224/224), done.
remote: Compressing objects: 100% (158/158), done.
remote: Total 224 (delta 74), reused 216 (delta 66), pack-reused 0
Receiving objects: 100% (224/224), 42.20 KiB | 258.00 KiB/s, done.
Resolving deltas: 100% (74/74), done.
```

Again, make some changes. I'll reuse `README.md` for this example.

Inspect which files have changed using `h st`:

```
# h st
## master...origin/master
 M README.md
```

See the diff using `h d`:

    # h d
    diff --git README.md README.md
    index d837090..a48fdc3 100644
    --- README.md
    +++ README.md
    @@ -123,3 +123,5 @@ Then:
    ```
    MY_GITHUB_USER="Svedrin"
    ```
    +
    +Hello! I'm changing the README

Now, before commiting, create a branch:

```
# h br 0-feature-branch
Switched to a new branch '0-feature-branch'
```

Commit:

```
# h ci README.md -m "some changes"
[0-feature-branch a4559a2] some changes
 1 file changed, 2 insertions(+)
```

To switch between branches, run the `h use` command:

```
# h use master
Switched to branch 'master'
Your branch is up to date with 'origin/master'.
Already up to date.

# h use feature
Switched to branch '0-feature-branch'
```

Note that it's not necessary to specify an exact branch name for `h use`. It will search for matching branches, and if exactly one is found that matches, it will check out that branch. Otherwise, it'll complain.

Anyway, now push:

```
# h push
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 375 bytes | 375.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
To github.com:Svedrin/hgit.git
   478e94b..6f5cb68  0-feature-branch -> 0-feature-branch
```

Create a PR:

```
# h pr
```

This command will open a web browser window that displays the difference
between your current branch and `master`. This window includes a `Create PR`
button which will let you create a PR with a single click.

And finally, switch back to master:

```
# h use master
```

### Safer branching

Switching to `master` is important: If you omit it, your next PR will be based
on the changes of this old PR rather than the current `master`. Mostly, you
will not want this, but instead want to base new PRs on `master`. In fact,
this is so common that `hgit` actually prevents you from creating a branch
that is not based on master. So if I were to run `h br other-feature` without
having run `h use master` before, this is what `hgit` will say:

```
# h br other-feature
You're creating a branch while you're not on master. You probably don't want to do that, aborting.
If you do want to do this, run git checkout -b other-feature.
```

## Contributing to someone else's repo

If you want to contribute to someone else's repo, the basic workflow stays
exactly the same. So most of the time, by following the above steps, you'll
be good to go.

If the project is large enough to warrant using PRs (or the upstream simply
requires it), it is good practice to _not_ push your changes to the upstream
repository (even if you have write permission), but use a fork instead. This
is commonly referred to as the
[Forking Workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/forking-workflow).
GitHub has a nice "fork repository" button to make this easy.

### Summary of the workflow

Since `hgit` implements the Forking Workflow, here's a quick summary of how that workflow... well, works.

1. A developer forks a repository from an organization. This creates their own copy, that they can modify at will without impacting the organization's repository.

2. The upstream repository is cloned to the developer's local system, and the fork is added as a secondary source.

3. When the developer wants to make changes, all changes are commited to a new branch created locally.

4. The branch gets pushed to the fork rather than the organization's upstream repository.

5. The developer opens a pull request from the new branch in their fork to the organization's upstream repository.

6. The pull request gets reviewed and/or approved following the organization's standards, and is eventually merged into the upstream repository's `master` branch.

7. The developer then checks out upstream's `master` branch and pulls the latest changes from there.

This variant of the workflow has the benefit that it feels like you're working with the upstream repository directly. You don't need to keep the complexity in your head that in this repo, you're working with a fork.

### Example

Here's how to work with such a repo in practice. I'll use GitHub's
[Spoon-Knife](https://github.com/octocat/Spoon-Knife) repo as an example.

Before cloning the Repo, make sure you have created a Fork on GitHub in your own account.

Now, start by cloning the repo. Be sure to clone the upstream repo. _Do not clone your fork._

```
# h clone gh:octocat/Spoon-Knife
Cloning into 'spoon-knife'...
remote: Enumerating objects: 16, done.
remote: Total 16 (delta 0), reused 0 (delta 0), pack-reused 16
Receiving objects: 100% (16/16), done.
Resolving deltas: 100% (3/3), done.
From github.com:Svedrin/Spoon-Knife
 * [new branch]      change-the-title -> svedrin/change-the-title
 * [new branch]      master           -> svedrin/master
 * [new branch]      test-branch      -> svedrin/test-branch
```

Let's unpack that output, because a lot has happened here.

*   First:

    ```
    Cloning into 'spoon-knife'...
    ```

    `hgit` always converts repo names to lowercase. The local checkout will
    end up in a directory named `spoon-knife`, even though the upstream repo
    is called `Spoon-Knife`. This is because in Linux, names are case sensitive
    and I find it cumbersome having to remember which repos where spelled in
    uppercase.

*   Then:

    ```
    remote: Enumerating objects: 16, done.
    remote: Total 16 (delta 0), reused 0 (delta 0), pack-reused 16
    Receiving objects: 100% (16/16), done.
    Resolving deltas: 100% (3/3), done.
    ```

    Nothing special about these, this is just `git` cloning the upstream repo.

*   Next:

    ```
    From github.com:Svedrin/Spoon-Knife
    * [new branch]      change-the-title -> svedrin/change-the-title
    * [new branch]      master           -> svedrin/master
    * [new branch]      test-branch      -> svedrin/test-branch
    ```

    These are noteworthy: `hgit` has checked if your account has a fork of
    this repo. It found one, so it was nice enough to add it as a remote:

    ```
    # git remote -v
    origin  git@github.com:octocat/Spoon-Knife.git (fetch)
    origin  git@github.com:octocat/Spoon-Knife.git (push)
    svedrin git@github.com:Svedrin/Spoon-Knife.git (fetch)
    svedrin git@github.com:Svedrin/Spoon-Knife.git (push)
    ```

    Also, it ran `git fetch svedrin`, so that it knows about the branches
    in the fork.

It is important to understand that `hgit` knows about forks, and changes
its behavior when a fork exists to make working with them easier. Most importantly,
when a fork exists:

*   `hgit` will not let you commit to the `master` branch anymore. Repos that
    use forks and PRs usually prohibit pushing to `master`, or at the very least
    it will be severely frowned upon. This is why, when a fork exists, `hgit`
    will flat-out refuse to commit to `master`:

    ```
    # h use master
    # h ci README.md -m "this will fail"
    You have a fork and you're commiting to master. You probably don't want to do that, aborting.
    ```

    To make commits, you will need to create a branch first using `h br`.

*   `h push` will refuse to do anything on `master`:

    ```
    # h push
    You have a fork and you're pushing to master. You probably don't want to do that, aborting.
    If you do want to do this, run h push origin.
    ```

    Other branches, it will automatically push to your fork rather than upstream,
    without the necessity for you to manually specify this:

    ```
    # h use feature
    Switched to branch '0-feature-branch'
    # h push
    Enumerating objects: 5, done.
    Counting objects: 100% (5/5), done.
    Delta compression using up to 8 threads
    Compressing objects: 100% (3/3), done.
    Writing objects: 100% (3/3), 350 bytes | 350.00 KiB/s, done.
    Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
    remote: Resolving deltas: 100% (1/1), completed with 1 local object.
    remote: 
    remote: Create a pull request for '0-feature-branch' on GitHub by visiting:
    remote:      https://github.com/Svedrin/hgit/pull/new/0-feature-branch
    remote: 
    To github.com:Svedrin/hgit.git
    * [new branch]      0-feature-branch -> 0-feature-branch
    Branch '0-feature-branch' set up to track remote branch '0-feature-branch' from 'svedrin'.
    ```

    Basically, `hgit` will keep your upstream safe when a fork exists.

*   `h pr` will of course take forks into account, and make sure you end up filing
    your PR in the upstream repo rather than in your fork.

The design goal of `hgit` is that no matter how the repo is set up, you can use
the same commands (`clone`, `pull`, `br`, `st`, `d`, `ci`, `push`, `pr`) and it'll
always just do the right thing.

So without further ado, let's go ahead and make some changes in a feature branch:

```
# h br 0-feature-branch
Switched to a new branch '0-feature-branch'

# h ci README.md -m "some changes"
[0-feature-branch a4559a2] some changes
 1 file changed, 2 insertions(+)

# h push
Enumerating objects: 5, done.
Counting objects: 100% (5/5), done.
Delta compression using up to 8 threads
Compressing objects: 100% (3/3), done.
Writing objects: 100% (3/3), 350 bytes | 350.00 KiB/s, done.
Total 3 (delta 1), reused 0 (delta 0), pack-reused 0
remote: Resolving deltas: 100% (1/1), completed with 1 local object.
remote: 
remote: Create a pull request for '0-feature-branch' on GitHub by visiting:
remote:      https://github.com/Svedrin/hgit/pull/new/0-feature-branch
remote: 
To github.com:Svedrin/hgit.git
* [new branch]      0-feature-branch -> 0-feature-branch
Branch '0-feature-branch' set up to track remote branch '0-feature-branch' from 'svedrin'.

# h pr
```

Easy-going, right? :)

## Working with someone else's changes

Suppose you're part of an organization, you have set up a repo with a fork as described above,
and you're collaborating with other people who are using the same process. Eventually, you'll
want to check out a feature branch from someone else in your local working copy.

First of all, here are the commands to run:

    h collab-with <other-person>

This will guess the URL for the other person's fork of this repo, and add it as a `remote`.

    h use <other-person> 123-feature-branch

`hgit` will search for branches in their fork containing the string "123-feature-branch", and
if exactly one branch matches, check out that branch. Otherwise it will show you a list of
branches that match, and ask you to clarify which one you want to check out.

Note that `hgit` will _not_ load the full list of _all_ the branches from the remote. This
will avoid pulling unrelated branches into your local working copy that you are not interested in.

Now you can make changes and, like before, use a plain `h push` to push them back into their fork.


# Notable differences between `hgit` and `git`

`hgit` is opinionated in the sense that it hides lots of stuff that `git` throws at you, and even redefines some commands completely:

* `h branch` implies `git checkout` of that newly-created branch. `h checkout` cannot create branches.
* `h change` doesn't exist in git, and combines `diff` and `commit` into a single command because I use them interchangeably.
* `h diff` has a `-c` option that lets you view an existing commit as a diff.
* `h commit` does not have `-a` because I find it confusing: "wait, does that also add stuff?". If you want to commit "everything", use `h ci .`.
* `h uncommit` and `h forget` don't exist in git, but I wish they did.
* no rebase. (See below.)
* `h use master` implicitly checks for branches that have been merged and removes them from your working copy.
* `git status` is way too long and hard to read - `h st` is both a shorter command and provides way more concise output.
* `hgit` prevents you from getting into "detached HEAD state" (which honestly doesn't sound like a particularly good state to be in). If you want to check out an old commit, `hgit` will implicitly create a branch to track new commits in. If you want to check out files from a certain commit, use `h cat`.
* Tags: `hgit` defaults to using annotated tag objects rather than lightweight local tags.

It is thus focused on making your _everyday_ life with git easier, rather than fully supporting everything that git has to offer.

## Why is there no `rebase`?

I've come to completely avoid `git rebase` for the following reasons:

* When you're working on a branch on multiple machines and you want to sync changes back and forth between them, `rebase` creates a hassle because you will no longer be able to blindly run `git pull`. Instead, you have to pass the `--rebase` option when a rebase has happened. This is annoying, especially when multiple people are working on the same branch.
* It's unnecessary: Just merge from master to update the feature branch, and squash your commits when merging back to master. GitHub has a button for that now!

# Compatibility with git

`hgit` is just a shell script that works on top of git commands. You can switch back and forth anytime. However, `hgit` does expect the local repo to be set up in a certain way, and if you disturb that, you'll find that commands don't work anymore and you'll have to resort to their underlying `git` counterparts fnord.

# Config

`hgit` requires a config file in `~/.hgitrc` that defines the name of your GitHub user:

```
MY_GITHUB_USER="Svedrin"
```

It will prompt you for the user name and create the configuration file automatically if it doesn't exist.
