# hgit - Git for Humans

Opinionated micro-porcelain for git. Assumes that you're working with GitHub, but tries not to fail too badly in case you don't.

## Opinionated?

`hgit` is opinionated in the sense that it hides lots of stuff that `git` throws at you, and even redefines some commands completely:

* `hgit branch` implies `git checkout` of that newly-created branch. `hgit checkout` cannot create branches.
* `hgit change` doesn't exist in git, and combines `diff` and `commit` into a single command because I use them interchangeably.
* `hgit diff` has a -c option that lets you view an existing commit as a diff.
* `hgit commit` does not have `-a` because I find it confusing: "wait, does that also add stuff?".
* `hgit use` and `hgit forget` don't exist in git, but I wish they did.
* no rebase. (See below.)
* `hgit use master` performs an implicit `fetch --prune` from your fork so you don't have to.
* `hgit` prevents you from running into situations that are weirdly more complex than you'd anticipate (wtf is a "detached HEAD"!?)

It is thus focused on making your _everyday_ life with git easier, rather than fully supporting everything that git has to offer.

## Y u no rebase?

I've come to completely avoid `git rebase` for the following reasons:

* Pretending that some part of history didn't happen is precisely the antithesis of what a version control system should be doing.
* `rebase` creates a huge mess when you're working on a branch from multiple machines, and you want to sync changes back and forth between them.
* It's completely unnecessary: Just merge from master, and squash your commits when merging back to master. GitHub has a button for that now!

## Other things about git I find aggravating

* `git status` is way too long - `hgit st` is both a shorter command and provides way more concise output.
* `clone` should clone, but also add your fork as a remote if you have one.
* `push` and `pull` should default to using into your fork (if one exists), and just KNOW the damn branch name (because why on earth would it be different from what you have locally?).
* I'd love me a command for listing remote branches without fetching them into my clone, then fetching + pulling + switching to one that matches a certain pattern. That's what `hgit use` does.
* GitHub recently started auto-deleting branches after their PR has been merged. Why does it take me a `git fetch -p` to get rid of the local ones?
* I'd like to be able to use `git branch` to create a branch, rather than having to _check out_ a thing that does not yet exist, and _warn_ git that "hey, that thing that I'm about to check out, it doesn't exist yet, so please go ahead and create a branch by the same name that you _then_ can check out." I mean come on, srsly?
* Tags. Git defaults to creating a "lightweight" local tag, which is completely useless. And when you created a non-useless tag, you'll find that getting it published is _also_ way more involved than it should be.

# Is it for me?

hgit is probably for you if you liked the HG and SVN CLIs, and you're used to cloning your repos something like this:

    git clone git@github.com:octocat/Spoon-Knife.git
    cd Spoon-Knife
    git remote add svedrin git@github.com:Svedrin/Spoon-Knife.git
    git remote add otherfolks git@github.com:OtherFolks/Spoon-Knife.git
    git remote add someoneelse git@github.com:SomeOneElse/Spoon-Knife.git

If this sounds vaguely familiar, hgit may work for you. If not, then many of hgit's assumptions are probably going to bite you rather than help you.


# Workflow for a repo of your own (you own it)

Well, this one's pretty boring - the commands are just way less obnoxious, which you'll find out while using `hgit`, so give it a try :)


# Workflow for a repo of some org that you want to fork

## Clone the repo

Go ahead and do:

    hgit clone git@github.com:octocat/Spoon-Knife.git

This will:

* `git clone git@github.com:octocat/Spoon-Knife.git spoon-knife` (the repo name gets lowercased before cloning)
* Check if you have a fork, and if so:
* `cd spoon-knife`
* `git remote add <your-name> git@github.com:<your-name>/Spoon-Knife.git`
* `git fetch <your-name>`

## Make some changes

    hgit branch 123-some-issue                  # creates new branch
    vi index.html
    hgit st                                     # shows that index.html is modified
    hgit c                                      # shows a full diff of the workspace
    hgit c index.html                           # shows a diff only of index.html
    hgit c index.html -m "made some changes"    # commits index.html
    hgit push                                   # pushes the branch to your fork
    hgit pr                                     # opens your browser so you can submit a PR
    hgit use master                             # switch back to master

## Pull changes from an existing branch

This is useful if you're working on the same branch on multiple machines. To clone and switch to an existing branch that may or may not exist locally:

    hgit use 123                                # switches to your fork's 123-some-issue branch
    hgit pull                                   # pulls the branch from your fork (done by `use` if it doesn't exist)
    vi index.html
    hgit c index.html -m "made more changes"    # commits index.html
    hgit push                                   # pushes the branch to your fork
    hgit use master                             # switch back to master

## Pull someone else's changes

    hgit collab-with <other-person>
    hgit use <other-person> 123

This will:

* `git remote add <other-person> git@github.com:<other-person>/Spoon-Knife.git`
* Search for branches in their fork containing the string "123", without fetching _all_ their branches to your local copy
* `git fetch <other-person> 123-this-branch-matched`
* `git checkout 123-this-branch-matched`

Then:

    vi index.html
    hgit c index.html -m "made more changes"    # commits index.html
    hgit push                                   # pushes the branch to their fork


# Compatibility with git

`hgit` is just a shell script that works on top of git commands. You can switch back and forth anytime. However, `hgit` does expect the local repo to be set up in a certain way, and if you disturb that, you'll find that commands don't work anymore and you'll have to resort to their underlying `git` counterparts.


# Config

`hgit` requires a config file in `~/.hgitrc` that defines the name of your GitHub user:

```
MY_GITHUB_USER="Svedrin"
```
