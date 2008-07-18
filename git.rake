#
#  rakefile intended to make handling multiple git submodules easy
#
#  this code is made available under the MIT License (see MIT-LICENSE.txt)
#  Copyright (c) 2007,2008 Mike Dalessio <mike@csa.net>
#

#  for nice, consistent output when we run commands
def puts_cmd(dir, cmd)
  puts "(#{dir}) [#{cmd}]"
end

#  discover list of submodules, and invoke callback on each pathname
def for_each_submodule &block
  status = %x{git submodule status}
  # status.each {|line| puts line unless line =~ /^ /} # print if any are out of sync with origin. [i find i ignore this. YMMV. -mike]
  status.each {|line| yield line.split()[1] }
end

#  for each submodule, chdir to that dir and invoke callback,
def for_each_submodule_dir &block
  for_each_submodule { |dir| Dir.chdir(dir) { yield dir } }
end

#  check if git repo needs to be pushed to origin.
#  works for submodules and superproject.
def alert_if_needs_pushing(dir = Dir.pwd)
  Dir.chdir(dir) {puts "WARNING: #{dir} needs to be pushed to remote origin" if needs_pushing? }
end

#  boolean function - does repo need pushing to origin?
#  based simply on whether the diff is non-blank. note that this may require a 'pull' to be in sync with origin.
def needs_pushing?(dir = Dir.pwd)
  rval = false
  branches ||= %x{git branch -r}.split # yeah, slow. should we cache it?
  branch = get_branch
  if branches.include? "origin/#{branch}"
    Dir.chdir(dir) do
      rval = (%x{git diff "#{branch}"..origin/"#{branch}"}.size > 0)
    end
  end
  rval
end

#  based on 'git status' output, does this repo contain changes that need to be committed?
#  optional second argument is a specific file (or directory) in the repo.
def needs_commit?(dir = Dir.pwd, file = nil)
  rval = false
  Dir.chdir(dir) do
    status = %x{git status}
    if file.nil?
      rval = true unless status =~ /nothing to commit \(working directory clean\)|nothing added to commit but untracked files present/
      if status =~ /nothing added to commit but untracked files present/
        puts "WARNING: untracked files present in #{dir}"
        show_changed_files(status)
      end
    else
      rval = true if status =~ /^#\t.*modified:   #{file}/
    end
  end
  rval
end

#  when passed a 'git status' output report, only tell me what i really need to know.
def show_changed_files(status)
  status.each_line do |line|
    if line =~ /^#\t/ # only print out the changed files (I think)
      if line =~ /new file:|modified:|deleted:/
        puts "     #{line}" 
      else
        puts "     #{line.chop}\t\t(may need to be 'git add'ed)" 
      end
    end
  end
end

#  figure out what branch the pwd's repo is on
def get_branch(status = `git status`)
  branch = nil
  if match = Regexp.new("^# On branch (.*)").match(status)
    branch = match[1]
  end
end

#  minimal set of git commands, for which we'll filter the output
vanilla_git_commands = %w{status diff commit push pull}

#  vanilla command #1
def git_status(dir = Dir.pwd)
  Dir.chdir(dir) do
    status = `git status`
    branch = get_branch(status)
    changes = "changes need to be committed" unless status =~ /nothing to commit \(working directory clean\)/
    unless changes.nil?
      printf "%-40s %s\n", "#{dir}:", [branch,changes].compact.join(", ")
      show_changed_files(status)
    end
  end
end

#  vanilla command #2
def git_diff(dir = Dir.pwd)
  Dir.chdir(dir) do
    puts_cmd dir, "git diff"
    system "git --no-pager diff"
  end
end

#  vanilla command #3
def git_commit(dir = Dir.pwd)
  Dir.chdir(dir) do
    if needs_commit? dir
      puts_cmd dir, "git commit"
      # -e to fire up editor, but -m to initialize it with a reminder of what directory we're committing.
      system "git commit -a -v -m '\# #{dir}' -e"
    end
  end
end

#  vanilla command #4
def git_push(dir = Dir.pwd)
  Dir.chdir(dir) do
    if needs_pushing?
      puts_cmd dir, "git push"
      status = %x{git push}
      puts status unless status =~ /Everything up-to-date/
    end
  end
end

#  vanilla command #5
def git_pull(dir = Dir.pwd)
  Dir.chdir(dir) do
    if get_branch == "master"
      puts_cmd dir, "git pull"
      status = %x{git pull}
      puts status unless status =~ /Already up-to-date/
    end
  end
end

namespace :git do
  namespace :sub do
    
    #  metacode
    vanilla_git_commands.each do |cmd|
      desc "git #{cmd} for submodules"
      task cmd do
        for_each_submodule_dir do |dir|
          eval "git_#{cmd}"
          alert_if_needs_pushing
        end
      end
    end

    desc "Execute a command in the root directory of each submodule. Requires DO='command' environment variable."
    task :for_each do
      command = ENV['CMD'] || ENV['DO']
      if command.nil? or command.empty?
        puts "ERROR: no DO='command' specified."
      else
        for_each_submodule_dir do |dir|
          puts_cmd dir, command
          rcode = system command
          if ENV['IGNERR'].nil? and (rcode == false || $? != 0)
            puts "ERROR: command failed with exit code #{$?}"
            exit $?
          end
        end
      end
    end

  end # namespace :sub


  #  needs to be declared before the superproject metacode
  task :status => [:branch]

  #  metacode. note commit is not handled generically.
  (vanilla_git_commands - ["commit"]).each do |cmd|
    desc "git #{cmd} for superproject and submodules"
    task cmd => "sub:#{cmd}" do
      eval "git_#{cmd}"
      alert_if_needs_pushing
    end
  end

  #  special code for commit, depends on update.
  desc "git commit for superproject and submodules"
  task :commit => ["sub:commit","update"] do
    git_commit
  end

  #  bee-yootiful commit log handling.
  desc "Update superproject with current submodules"
  task :update => ["sub:push"] do
    require 'tempfile'
    for_each_submodule do |dir|
      if needs_commit?(Dir.pwd, dir)
        logmsg = nil
        currver = %x{git submodule --cached status | fgrep #{dir} | cut -c2- | cut -d' ' -f1}.chomp
        newver = %x{git submodule status | fgrep #{dir} | cut -c2- | cut -d' ' -f1}.chomp
        #  get all the commit messages from the submodule, so we can tack them onto our superproject commit message.
        Dir.chdir(dir) do
          puts "git --no-pager log #{currver}..HEAD"
          logmsg = %x{git --no-pager log #{currver}..#{newver}}
        end
        commitmsg = "updating to latest #{dir}\n\n" + logmsg.collect{|line| "> #{line}"}.join;
        puts_cmd Dir.pwd, "git commit #{dir}"
        tp = ''
        Tempfile.open('rake-git-update') {|tf| tf.write(commitmsg) ; tp = tf.path }
        system "git commit -F #{tp} #{dir}"
      end
    end
  end
  
  desc "Run command in all submodules and superproject. Requires DO='command' environment variable."
  task :for_each => "sub:for_each" do
      command = ENV['CMD'] || ENV['DO']
      if command.nil? or command.empty?
        puts "ERROR: no DO='command' specified."
      else
        puts_cmd Dir.pwd, command
        rcode = system(command)
        if rcode == false || $? != 0
          puts "ERROR: command failed with exit code #{$?}"
        end
      end
  end

  #  sanity check.
  task :branch do
    branches = {}
    for_each_submodule_dir do |dir|
      b = get_branch
      branches[b] ||= []
      branches[b] << dir
    end
    b = get_branch
    branches[b] ||= []
    branches[b] << "superproject"
    if branches.size == 1
      puts "All repositories are on branch '#{branches.keys.first}'"
    else
      puts "WARNING: multiple branches present."
      branches.keys.each { |b| puts "WARNING: #{branches[b].size} on branch #{b}: #{branches[b].sort.join(', ')}" }
    end
  end

  #  i'm sure you have a strong opinion that i'm doing this wrong. well, me too.
  desc "Configure Rails for git"
  task :configure do
    system "echo '*.log' >> log/.gitignore"
    system "echo '*.db' >> db/.gitignore"
    system "mv config/database.yml config/database.yml.example"
    system "echo 'database.yml' >> config/.gitignore"
    system "echo 'session' >> tmp/.gitignore"
    system "echo 'cache' >> tmp/.gitignore"
    system "echo 'pids' >> tmp/.gitignore"
    system "echo 'sockets' >> tmp/.gitignore"
    system "echo 'plugin_assets' >> public/.gitignore"
    system "echo 'data' >> .gitignore"
  end

  desc "Tag superproject and submodules. Requires TAG='tag-name'."
  task :tag do
    unless tag = ENV['TAG']
      puts "ERROR: no TAG='tag-name' specified."
    else
      for_each_submodule_dir do |dir|
        system "git tag #{tag}"
        system "git push --tags"
      end
      system "git tag #{tag}"
      system "git push --tags"
    end
  end

end
