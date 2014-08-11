# vim: autoindent tabstop=2 shiftwidth=2 expandtab softtabstop=2 filetype=ruby
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#
# Author::  Javi Roman <javiroman@redoop.org>
# Website:: http://www.redoop.org

require 'erb'
require 'git'
require 'logger'
require 'fileutils'

module Environment
  class PuppetEnvironment
    def initialize(outputHandler)
      @outputHandler = outputHandler
      puts "Setting up the catalog environemt"
    end

    #
    # https://github.com/schacon/ruby-git
    #
    # FIXME: error handle and sanity copy.
    def createPuppetMasterEnv(json_loaded)
      git_working_dir = json_loaded['environment_path']
      git_buildoop_branch = json_loaded['environment_branch']
      puppet_environment = json_loaded['environment_cluster']

      @outputHandler.msgOutput 'Patch to environments: ' + git_working_dir
      @outputHandler.msgOutput 'Based on Buildoop branch: ' + git_buildoop_branch

      # git staff
      g = Git.open(git_working_dir, :log => Logger.new(STDOUT))
      g.branches.remote
      g.branch(git_buildoop_branch).checkout

      if confirm_action? "the /etc/puppet/environments/#{puppet_environment} will be erased,"
        FileUtils.rm_rf("/etc/puppet/environments/#{puppet_environment}")

        # copy environment to puppet location
        FileUtils.cp_r git_working_dir + "/all", 
            '/etc/puppet/environments', :verbose => true
        FileUtils.cp_r git_working_dir + "/cluster-name", 
            "/etc/puppet/environments/#{puppet_environment}", :verbose => true

        fillExtlookupCSV json_loaded
      end
    end

    def fillExtlookupCSV(json_loaded)
      @buildoop_yumrepo_uri = json_loaded['buildoop_repository']
      @hadoop_security_authentication = 'simple'
      @hadoop_ha_nameservice = json_loaded['cluster_layout']['name'] 
      @hadoop_namenode_nn1 = json_loaded['cluster_layout']['batch']['nn1']['hostname']
      @hadoop_namenode_nn2 = json_loaded['cluster_layout']['batch']['nn2']['hostname']
      @hadoop_resourcemanager = json_loaded['cluster_layout']['batch']['rm']['hostname']

      csv_erb = "/etc/puppet/environments/#{json_loaded['environment_cluster']}/extdata/site.csv.erb"
      csv = "/etc/puppet/environments/#{json_loaded['environment_cluster']}/extdata/site.csv"

      template_file = File.open(csv_erb, 'r').read
      erb = ERB.new(template_file)
      
      File.open(csv, 'w+') { 
        |file| file.write(erb.result(binding)) 
      }

    end

    def confirm_action?(msg)
      cont = true
      while cont
        print msg + " are you sure? [y/n]: "
        case gets.strip
          when 'Y', 'y', 'j', 'J', 'yes' 
            cont = false
          when /\A[nN]o?\Z/
            return false
        end
      end
      true
    end



  end # class PuppetEnvironment
end



