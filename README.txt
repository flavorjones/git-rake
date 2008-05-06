= git.rake =

Hi. Thanks for taking a look at git.rake, a set of rake tasks that
should help you manage multiple git submodules.

For posterity, the original blog post detailing its use is here:
     <TODO>
That content is reproduced here for you. Because I'm a nice guy.

To install, just do something like:
        git submodule add <TODO> lib/tasks/git-rake


= What git.rake Is =

A set of rake tasks that will:

        a) Keep your superproject in synch with multiple submodules,
           and vice versa. This includes branching, merging, pushing
           and pulling to/from a shared server, and
           committing. (Biff!)

        b) Keep a description of all changes made to submodules in the
           commit log of the superproject. (Bam!)

        b) Display the status of each submodule and the superproject
           in an easily-scannable representation, suppressing what you
           don't want or need to see. (Pow!)

        c) Execute arbitrary commands in each repository (submodule
           and superproject), terminating execution if something
           fails. (Whamm!)

        d) Configure a rails project for use with git. (Although, you've seen
           that elsewhere and are justifiably unimpressed.)


= Prerequisites =

If you're not sure how to add a submodule to your repo, or you're not
sure what a submodule is, take a quick trip over to

        http://git.or.cz/gitwiki/GitSubmoduleTutorial

and then come back. In fact, even if you ARE familiar with submodules,
it's probably worth reviewing.


= The Primary Problems We're Trying to Solve Here =

Let's start with stating our basic assumptions:

        1) you're using a shared repository (like github)
        2) you're actively developing in one or more submodules

This model of development can get very tedious very quickly if you
don't have the right tools. Everytime you decide to "checkpoint" and
commit your code either locally or up to the shared server, you have
to:

        * do a lot of iterating through your submodules, doing things
           like:
                * making sure you're on the right branch,
                * making sure you've pulled other people's changes
                  down from the server,
                * making sure that you've committed your changes,
                * and pushed all your commits
        * and then making sure that your superproject's references to
          the submodules have also been committed and pushed.

If you do this a few times, it's tedious and error-prone. You could
mistakenly push a version of the superproject that refers to a _local_
commit of a submodule. When people try to pull that down from the
server, all hell will break loose because that commit won't exist for
them. Ugh!


= Simple Solution =

OK, fixing this issue sounds easy. All we have to do is develop some
primitives for iterating over the submodules (and optionally the
superproject), and then throw some actual functionality on top for
sanity checking, pulling, pushing and committing.


= The Tasks =

git-rake presents a set of tasks for dealing with the submodules:
        git:sub:commit     # git commit for submodules
        git:sub:diff       # git diff for submodules
        git:sub:for_each   # Execute a command in the root directory of each submodule. Requires CMD='command' environment variable.
        git:sub:pull       # git pull for submodules
        git:sub:push       # git push for submodules
        git:sub:status     # git status for submodules

And the corresponding tasks that run for the submodules PLUS the superproject:
	git:commit         # git commit for superproject and submodules
	git:diff           # git diff for superproject and submodules
	git:for_each       # Run command in all submodules and superproject. Requires CMD='command' environment variable.
	git:pull           # git pull for superproject and submodules
	git:push           # git push for superproject and submodules
	git:status         # git status for superproject and submodules

It's worth noting here that most of these tasks do pretty much just as
advertised, in some cases less, and certainly nothing more (well,
maybe a sanity check or two, but no destructive actions).

However, git:commit depends on git:update, which has some pixie dust
in it. More on this below.

And that leaves only the following specialty tasks:
        git:configure      # Configure Rails for git
        git:update         # Update superproject with current submodules
        
The first is straight forward: configuration of a rails project for
use with git.

The other, git:update, does two powerful things:

1) (Only if this branch is 'master') Submodules are pushed to the
shared server. This guarantees that the superproject will not have any
references to local-only commits.

2) For each submodule, take the git-log for all uncommitted (in the
superproject) revisions, and jam them into a superproject commit
message.

Here's an example of such a superproject commit message:

---
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
----

Excellent! Not only did git:update generate a useful log message for
me (indicating that we're updating to the latest submodule version),
but it's also telling me exactly what changes are included in that
commit!


= A Note on Branching and Merging =

Note that there are no tasks for handling branching and merging! This
is intentional. It can be a very dangerous thing to try to read your
mind about actions on branches, and I'm just not up to it today.

For example, let's say I issued a command to tell all submodules to
copy the current branch ('master') to a new branch ('foo') (this would
be the equivalent of 'git checkout -b foo master'), but one of the
submodules already has a branch named foo!

Do we reduce this action to a simple 'git checkout foo'? That could be
very unexpected if we a) forgot we had a branch named 'foo' and b)
that branch is very different from 'master'.

Well, then -- we can delete (or rename) the existing 'foo' branch and
follow that up by copying 'master' to 'foo'. But then we're silently
renaming branches that a) could be upstream on the shared server or b)
we intended to keep around, but forgot to git-stash.

In any case, my point is that it can get complicated, and so I'm
punting. If you want to copy branches or do simple checkouts, you can
use the git:for_each command.


= Everyday Use of git:rake =

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
        /home/mike/git-repos/demo1/vendor/plugins/pharos_library: master, changes need to be committed
             #	deleted:    tasks/rake/git.rake		(may need to be 'git add'ed)

You'll notice first of all that, despite having 14 submodules, I'm
only seeing output for the ones that need commits. It will tell me
that all submodules are on the same branch. It's even smart enough to
tell me if a file should be git-added.

I'll have to manually chdir to the one submodule and git-add a file,
but once that's done, I can commit my changes by running:

        $ rake git:commit

which will run 'git commit -a -v' for each submodule, firing up the
editor for commit messages along the way, followed by pushing each
submodule up to the shared server, and then automagically creating
verbose commit logs for the superproject.

To pull changes from the shared server:

        $ rake git:pull

You'll notice that the output of this command is filtered, so if no
changes were pulled, you'll see no output. Silence is golden.

To push?

        $ rake git:push

Not only will this be silent if there's nothing to push, but the rake
task is smart enough to not even attempt to push to the server if
master is no different from origin/master. So it's silent and fast.

Let's say I want to copy the current branch, 'master', to a new
branch, 'working'.

        $ rake git:for_each CMD='git checkout -b working master'

If the command fails for any submodules, the rake task will terminate
immediately.

Merging changes from 'working' back into 'master' for every submodule
(and the superproject)?

        $ rake git:for_each CMD='git checkout master'
        $ rake git:for_each CMD='git merge working'


= What git.rake Doesn't Do =

A couple of things that come quickly to mind that git.rake should
probably do:

        * Push to the shared server for ANY branch that we're tracking
          from a remote branch.

        * Be more intelligent about when we push to the server. Right
          now, the code pushes submodules to the shared server every
          time we want to commit the superproject. We might be able to
          get away with only pushing the submodules when we push the
          superproject.

        * There should probably be some unit/functional tests.

Anyway, the code is all up on github. Go hack it, and send back patches!

--
mike dalessio
mike@csa.net
