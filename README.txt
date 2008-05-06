= git.rake =

Hi. Thanks for taking a look at git.rake, a set of rake tasks that
should be able to help you manage multiple git submodules. (At least,
they help me, which is why I wrote them.) 

For posterity, the original blog post detailing its use is here:
     <TODO>
but really, that content is reproduced here for you. Because I'm a
nice guy.

= What It Is =

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
           that elsewhere and are unimpressed.)

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

Well, this model of development can get very tedious very quickly if
you don't have the right tools. Everytime you decide to "checkpoint"
and commit your code either locally or up to the shared server, you
have to:

        * do a lot of iterating through your submodules, doing things
           like:
                * making sure you're on the right branch,
                * making sure you've pulled other people's changes
                  down from the server,
                * making sure that you've committed your changes,
                * and pushed all your commits
        * and then making sure that your superproject's references to
          the submodules have also been committed and pushed.

If you do this a few times, you quickly get tired of it. Really. Even
worse, you could mistakenly push a version of the superproject that
refers to a _local_ commit of a submodule. When people try to pull
that down from the server, all hell will break loose because that
commit won't exist for them. Ugh!

= Simple Solution =

OK, fixing this issue should be easy. All we have to do is develop
some primitives for iterating over the submodules (and optionally the
superproject), and then throw some actual functionality on top for
sanity checking, pulling, pushing and committing.

= The Tasks =

Let's see what we have:

$ rake -T git

So, basically, we have a set of tasks for dealing with the submodules:
        git:sub:commit
        git:sub:diff
        git:sub:for_each
        git:sub:pull
        git:sub:push
        git:sub:status
And corresponding tasks that run for the submodules and the superproject.
        git:commit
        git:diff
        git:for_each
        git:pull
        git:push
        git:status
--
mike dalessio
mike@csa.net
