##############################################################################
# Copyright (c) 2013-2014, OmniTI Computer Consulting, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name OmniTI Computer Consulting, Inc. nor the names
#       of its contributors may be used to endorse or promote products
#       derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##############################################################################


require 'chef/handler'
require 'chef/resource/directory'

module OmniTI
  class LastGoodRun < ::Chef::Handler

    attr_reader :config

    def initialize(config)
      @config = config || {}
      @config[:path] ||= "/var/chef/reports"
      @config
    end

    def report

      file_path = File.join(config[:path], "last-good-run.json")

      if exception
        # Silently return - we only want to update the file on a successful run
        return
      else
        Chef::Log.info("Creating Last Good Run report at #{file_path}")
      end
      

      # Dump report file
      build_report_dir
      savetime = Time.now.strftime("%Y%m%d%H%M%S")
      File.open(file_path, "w") do |file|
        file.puts Chef::JSONCompat.to_json_pretty(data)
      end

      # Inject into MOTD if requested
      if config[:update_motd] then
        Chef::Log.info("Updating MOTD with last good run info")
        prefix = 'Last OK chef run:  '
        unless system("grep '#{prefix}' /etc/motd > /dev/null") then
          system "echo '#{prefix}' >> /etc/motd"
        end

        info = Time.new.strftime('%F %T %Z')
        info += ' (' + '%0.2f' % run_status.elapsed_time.to_s() + ' sec, ' + run_status.updated_resources.length.to_s() + ' changes)'

        require 'chef/util/file_edit'
        motd = Chef::Util::FileEdit.new('/etc/motd')
        motd.search_file_replace_line(prefix, prefix + info)
        motd.write_file()

      end

    end

    def build_report_dir
      unless File.exists?(config[:path])
        FileUtils.mkdir_p(config[:path])
        File.chmod(00755, config[:path])
      end
    end

  end
end

