# hgit - Git for Humans

opinionated micro-porcelain for git and probably hub
opinionated in the sense that it hides lotsa stuff and redefines commands completely:
* branch does a different thing
* change doesn't exist in git, and combines two pretty different commands
* diff has a -c option
* commit does not have -a and forces you to specify a path, even if just "."
* use, forget don't exist in git, but I wish they did
* no rebase
* "use master" performs implicit fetch --prune from your fork so you don't have to

status is way too long - st is a shorter command and provides more useful output

clone should clone, but also add your fork as a remote

push should default to pushing into your fork (if one exists), and just KNOW the fucking branch name
pull: same thing - fetch first?

command for listing remote branches, maybe even without fetching them, then fetching + pulling + switching to one that matches a certain pattern or something?
e.g. hgit use 116 -> "hmm, no such branch here, but in the svedrin fork there's one called 116-python-3, let's check out that one then"
after hgit use master: automatically fetch --prune to delete the now-probably-gone PR branch

hgit branch -> CREATE ONE rather than force me to check out a thing that does not yet exist, wtf


# Workflow for a repo of your own (you own it)

Well, this one's pretty boring - the commands are just way less obnoxious, which you'll find out while using `hgit`, so give it a try :)


# Workflow for a repo of some org that you want to fork

## Clone the repo

Do one of:

    hgit clone git@github.com:octocat/Spoon-Knife.git
    hgit fork  git@github.com:octocat/Spoon-Knife.git

This will:

* `git clone git@github.com:octocat/Spoon-Knife.git`
* If you do not yet have a fork, create one
* `cd Spoon-Knife`
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

    hgit use <other-person> 123

This will:

* `git remote add <other-person> git@github.com:<other-person>/Spoon-Knife.git`
* `git fetch <other-person> --filter 123`
* `git checkout <whatever branch matches the filter>`

Then:

    vi index.html
    hgit c index.html -m "made more changes"    # commits index.html
    hgit push                                   # pushes the branch to their fork

# Compatibility with git

`hgit` is just a shell script that works on top of git commands. You can switch back to git anytime. However, switching from plain git to `hgit` is a bit tricky because `hgit` does need some state information, mostly regarding which local branches belong to which remote. As long as you name your remotes in the way `hgit` expects (that is, lowercase your GitHub username), and you only work with branches that you either create or `use` through `hgit` rather than git directly, switching from git to `hgit` should work though.

# Config

`hgit` requires a config file in `~/.hgitrc` that defines the name of your GitHub user, after which your remotes will be named.

# State

`hgit` writes some state into `.git/hgitrc`. Let's hope git doesn't care, but knowing git, it probably gives zero fucks.
