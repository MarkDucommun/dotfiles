alias s="/usr/local/bin/subl"
alias subl="/usr/local/bin/subl -n"

alias gs="git status"
alias ga="git add"
alias gb="git branch"
alias gc="git commit"
alias gco="git checkout"
alias got="git"
alias get="git"
alias branch="echo $(git rev-parse --abbrev-ref HEAD)"
alias gitsync="~/Google\ Drive/giveforward/devtools/git-tools/sync"

alias ls="ls -G"
alias ll="ls -G -lhA"

alias be="bundle exec"
alias phpvm="ssh root@local-gf"

gcrp () {
  branch="`git branch | grep "^\* " | cut -d' ' -f2`"
  echo "git commit -am 'fixup this commit'"
  gc -am 'fixup this commit'
  echo "git rebase -i develop"
  git rebase -i develop
  echo "git push -uf origin $branch"
  git push -uf origin $branch
}

clone () {
  git clone git@github.com:giveforward/$1.git
}

# Unicorn Mist - NG server on & off
alias umon="cd ~/unicorn-mist && jruby --ng-server &"
alias umoff="kill -9 `lsof -i :2113 -t`"

unicorn_mist_spec() {
  jruby --ng -S bin/rspec --drb $1
}
alias umspec=unicorn_mist_spec

freshen_db() {
  echo '===== dropping gf_dev ======'
  psql -c 'drop database gf_dev;' -U postgres

  echo '===== dropping gf_test ======'
  psql -c 'drop database gf_test;' -U postgres

  echo '===== dropping gf_warehouse_dev ======'
  psql -c 'drop database gf_warehouse_dev;' -U postgres

  echo '===== dropping gf_warehouse_test ======'
  psql -c 'drop database gf_warehouse_test;' -U postgres

  echo '===== dropping gf_uh_test ======'
  psql -c 'drop database gf_uh_test;' -U postgres

  echo '===== create gf_dev ======'
  psql -c 'create database gf_dev;' -U postgres

  echo '===== create gf_test ======'
  psql -c 'create database gf_test;' -U postgres

  echo '===== create gf_warehouse_dev ======'
  psql -c 'create database gf_warehouse_dev;' -U postgres

  echo '===== create gf_warehouse_test ======'
  psql -c 'create database gf_warehouse_test;' -U postgres

  echo '===== create gf_uh_test ======'
  psql -c 'create database gf_uh_test;' -U postgres

  echo 'altering roles for databases...'
  psql gf_dev -c 'alter user gfwd with superuser;' -U postgres
  psql gf_test -c 'alter user gfwd with superuser;' -U postgres
  psql gf_warehouse_dev -c 'alter user gfwd with superuser;' -U postgres
  psql gf_warehouse_test -c 'alter user gfwd with superuser;' -U postgres
  psql gf_uh_test -c 'alter user gfwd with superuser;' -U postgres

  cd ~/mist
  be rake db:migrate && RAILS_ENV=test be rake db:migrate

  cd ~/heart
  RAILS_ENV=test be rake db:migrate
}

function removeFromPath() {
  export PATH=$(echo $PATH | sed -E -e "s;:$1;;" -e "s;$1:?;;")
}

function setjdk() {
  if [ $# -ne 0 ]; then
   removeFromPath '/System/Library/Frameworks/JavaVM.framework/Home/bin'
   if [ -n "${JAVA_HOME+x}" ]; then
    removeFromPath $JAVA_HOME
   fi
   export JAVA_HOME=`/usr/libexec/java_home -v $@`
   export PATH=$JAVA_HOME/bin:$PATH
  fi
}

function srspec() {
  #! /bin/bash
  RSPEC="bundle exec rspec"
  VERSION=$(cat ~/mist/.ruby-version)
  GEMSET=$(cat ~/mist/.ruby-gemset)
  rvm use ${VERSION}@${GEMSET}

  # Looking for nailgun
  lsof -i :2113 > /dev/null
  if [ $? == 0 ]; then
    echo Starting Nailgun...
    RSPEC="jruby --ng -S $RSPEC"
  fi

  # Looking for spork
  lsof -i :8989 > /dev/null
  if [ $? == 0 ]; then
    echo Starting Spork...
    RSPEC="$RSPEC --drb"
  fi

  CMD="$RSPEC $@"
  echo $CMD
  $CMD
}
