git.rake
=====

---

__Update 2008-05-21__: Tim Dysinger and Pat Maddox pointed out that git submodules are _inherently not well-suited for frequently updated projects._ Read the comments on the original blog post (URL below) for more details, and __please use git.rake with caution__ on projects where you can't guarantee a submodule's shared repository has not changed between 'pull' and 'push' operation.

---

Hi. Thanks for taking a look at *git.rake*, a set of rake tasks that
should help you manage multiple git submodules.

For posterity, the original blog post detailing its use is at

> [http://flavoriffic.blogspot.com/2008/05/managing-git-submodules-with-gitrake.html](http://flavoriffic.blogspot.com/2008/05/managing-git-submodules-with-gitrake.html)

but that content is reproduced here for you. Because I'm a nice guy.

To install, just do something like:

> git submodule add git://github.com/mdalessio/git-rake.git lib/tasks/git-rake

And to verify installation, just run:

> rake -T git

[mike dalessio, <mike@csa.net>]


Summary
-----
Managing git submodules is a hassle.

* You have to remember to push your submodules before you push your superproject.
* You have to duplicate log messages in the submodule and the superproject.
* It's difficult to see the status of each submodule, because 'git status' prints out so much cruft.
* It's difficult to manage the branches in each submodule.
* It's also a pain to generally run commands on each submodule (e.g., 'git checkout working')

git.rake makes all of these hassles go away by providing these tasks:

        rake git:commit        # git commit for superproject and submodules
        rake git:configure     # Configure Rails for git
        rake git:diff          # git diff for superproject and submodules
        rake git:for_each      # Run command in all submodules and superproject.
        rake git:pull          # git pull for superproject and submodules
        rake git:push          # git push for superproject and submodules
        rake git:status        # git status for superproject and submodules
        rake git:tag           # Tag superproject and submodules.
        rake git:update        # Update superproject with current submodules


Read on for implementation details and usage.

What git.rake Is
-----

A set of rake tasks that will:

* Keep your superproject in synch with multiple submodules, and vice
versa. This includes branching, merging, pushing and pulling to/from a
shared server, and committing. (Biff!)

* Keep a description of all changes made to submodules in the commit
log of the superproject. (Bam!)

* Display the status of each submodule and the superproject in an
easily-scannable representation, suppressing what you don't want or
need to see. (Pow!)

* Execute arbitrary commands in each repository (submodule and
superproject), terminating execution if something fails. (Whamm!)

* Configure a rails project for use with git. (Although, you've seen
that elsewhere and are justifiably unimpressed.)


Prerequisites
-----

If you're not sure how to add a submodule to your repo, or you're not
sure what a submodule is, take a quick trip over to [the Git Submodule
Tutorial](http://git.or.cz/gitwiki/GitSubmoduleTutorial), and then
come back. In fact, even if you ARE familiar with submodules, it's
probably worth reviewing.


The Problem We're Trying to Solve Here
-----

Let's start with stating our basic assumptions:

1. you're using a shared repository (like github)
2. you're actively developing in one or more submodules

This model of development can get very tedious very quickly if you
don't have the right tools, because everytime you decide to
"checkpoint" and commit your code (either locally or up to the shared
server), you have to:

* iterate through your submodules, doing things like:
  * making sure you're on the right branch,
  * making sure you've pulled changes down from the server,
  * making sure that you've committed your changes,
  * and pushed all your commits
* and then making sure that your superproject's references to the
submodules have also been committed and pushed.

If you do this a few times, you'll see that it's tedious and
error-prone. You could mistakenly push a version of the superproject
that refers to a _local_ commit of a submodule. When people try to
pull that down from the server, all hell will break loose because that
commit won't exist for them.

Ugh! This is monkey work. Let's automate it.

Simple Solution
-----

OK, fixing this issue sounds easy. All we have to do is:

* develop some primitives for iterating over the submodules (and
optionally the superproject),
* and then throw some actual functionality on top for sanity checking, pulling,
pushing and committing.

The Tasks
-----

git-rake presents a set of tasks for dealing with the submodules:

        git:sub:commit     # git commit for submodules
        git:sub:diff       # git diff for submodules
        git:sub:for_each   # Execute a command in the root directory of each submodule.\
                             Requires DO='command' environment variable.
        git:sub:pull       # git pull for submodules
        git:sub:push       # git push for submodules
        git:sub:status     # git status for submodules

And the corresponding tasks that run for the submodules PLUS the superproject:

        git:commit         # git commit for superproject and submodules
        git:diff           # git diff for superproject and submodules
        git:for_each       # Run command in all submodules and superproject. \
                             Requires DO='command' environment variable.
        git:pull           # git pull for superproject and submodules
        git:push           # git push for superproject and submodules
        git:status         # git status for superproject and submodules


It's worth noting here that most of these tasks do pretty much just
what they advertise, in some cases less, and certainly nothing more
(well, maybe a sanity check or two, but no destructive actions).

The exception is `git:commit`, which depends on `git:update`, and that has
some pixie dust in it. More on this below.

Leaving only the following specialty tasks to be explained:

        git:configure      # Configure Rails for git
        git:update         # Update superproject with current submodules

        
The first is simple: configuration of a rails project for use with
git.

The other, `git:update`, does two powerful things:

1. (Only if on branch 'master') Submodules are pushed to the shared
server. This guarantees that the superproject will not have any
references to local-only submodule commits.

2. For each submodule, retrieve the git-log for all uncommitted (in
the superproject) revisions, and jam them into a superproject commit
message.

Here's an example of such a superproject commit message:

        commit 17272d53c298bd6a8ccee6528e0bc0d62104c268
        Author: Mike Dalessio <mike@csa.net>
        Date:   Mon May 5 20:48:13 2008 -0400

                updating to latest vendor/plugins/pharos_library
    
                > commit f4dbbce6177de4b561aa8388f3fa9f7bf015fa0b
                > Author: Mike Dalessio <mike@csa.net>
                > Date:   Mon May 5 20:47:46 2008 -0400
                >
                >     git:for_each now exits if any of the subcommands fails.
                >
                > commit 6f15dee8c52ced20c98eef63b3f3fd1c29d91bbf
                > Author: Mike Dalessio <mike@csa.net>
                > Date:   Fri May 2 13:58:17 2008 -0400
                >
                >     think i've got the tempfile handling correct now. awkward, but right.
                >

Excellent! Not only did `git:update` automatically generate a useful log
message for me (indicating that we're updating to the latest submodule
version), but it's also __embedding original commit logs__ for all the
changes included in that commit! That makes it much easier to find a
specific submodule commit in the superproject commit log.


A Note on Branching and Merging
-----

Note that there are no tasks for handling branching and merging. This
is intentional! It could be very dangerous to try to read your mind
about actions on branches, and frankly, I'm just not up to it today.

For example, let's say I invented a task to copy the current branch
`master` to a new branch `foo` (the equivalent of `git checkout -b foo
master`) in all submodules, but one of the submodules already has a
branch named `foo`!

Do we reduce this action to a simple `git checkout foo` for that
submodule? That could yield unexpected results if we a) forgot we had
a branch named `foo` and b) that branch is very different from the
`master` we expected to copy.

Well, then -- we can delete (or rename) the existing `foo` branch and
follow that up by copying `master` to `foo`. But then we're silently
renaming (or deleting) branches that a) could be upstream on the
shared server or b) we intended to keep around, but forgot to
git-stash.

In any case, my point is that it can get complicated, and so I'm
punting. If you want to copy branches or do simple checkouts, you
should use the `git:for_each` command.

Everyday Use of git:rake
-----

In my day job, I've taken the vendor-everything approach and
refactored lots of common code (across clients) into plugins, which
are each a git submodule. My current project has 14 submodules, of
which I am actively coding in probably 5 to 7 at any one time. (Plenty
of motivation for creating git:rake right there.)

Let's say I've hacked for an hour or two and am ready to commit to
my local repository. Let's first take a look at what's changed:

        $ rake git:status

        All repositories are on branch 'master'
        /home/mike/git-repos/demo1/vendor/plugins/core: master, changes need to be committed
        #	modified:   app/models/user_mailer.rb
        #	public/images/mail_alert.png		(may need to be 'git add'ed)
        WARNING: vendor/plugins/core needs to be pushed to remote origin
        /home/mike/git-repos/demo1/vendor/plugins/pharos_library: master, changes need to be committed
        #	deleted:    tasks/rake/git.rake

You'll notice first of all that, despite having 14 submodules, I'm
only seeing output for the ones that need commits, and even that
output is minimal, listing only the specific files and not all the
cruft in the original message. It tells me that all submodules are on
the same branch. It's smart enough to tell me that a file may need to
be git-added. It will even alert me when a repo needs to be pushed to
the origin.

I'll have to manually `cd` to the submodule and git-add that one
file, but once that's done, I can commit my changes by running:

        $ rake git:commit

which will run `git commit -a -v` for each submodule, fire up the
editor for commit messages along the way, push each submodule to the
shared server, and then automagically create verbose commit logs for
the superproject.

To pull changes from the shared server:

        $ rake git:pull

When you run this command, you'll notice that the output is filtered,
so if no changes were pulled, you'll see no output. Silence is golden.

To push?

        $ rake git:push

Not only will this be silent if there's nothing to push, but the rake
task is smart enough to not even attempt to push to the server if
master is no different from origin/master. So it's silent and fast.

Let's say I want to copy the current branch, `master`, to a new
branch, `working`.

        $ rake git:for_each DO='git checkout -b working master'

If the command fails for any submodules, the rake task will terminate
immediately.

Merging changes from 'working' back into 'master' for every submodule
(and the superproject)?

        $ rake git:for_each DO='git checkout master'
        $ rake git:for_each DO='git merge working'


What git.rake Doesn't Do
-----

A couple of things that come quickly to mind that git.rake should
probably do:

* Push to the shared server for ANY branch that we're tracking from a
remote branch.

* Be more intelligent about when we push to the server. Right now, the
code pushes submodules to the shared server every time we want to
commit the superproject. We might be able to get away with only
pushing the submodules when we push the superproject.

* Parsing the output from various 'git' commands is prone to breakage
if the git crew starts modifying some of the strings.

* There should probably be some unit/functional tests. See previous
item.

Anyway, the code is all up on github. Go hack it, and send back patches!
