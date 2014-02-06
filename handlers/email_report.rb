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

module OmniTI
  class EmailReport < ::Chef::Handler

    attr_reader :options
    attr_reader :report_name

    def initialize(rpt_name, opts)
      @options = {}
      @options.merge! opts
      @report_name = rpt_name
    end

    def report

      # Chef::Log.info("options dump: #{@options.inspect()}")

      # If no recipients, add root to the list
      if @options['recipients'].empty? then
        @options['recipients'].push('root')
      end

      #------
      # Filter Changes
      #------
      filtered_changes = updated_resources
      unless @options['only_changes'].empty? then
        filtered_changes = filtered_changes.find_all do | resource |
          @options['only_changes'].detect { |regex| (resource.resource_name.to_s + '[' + resource.name + ']').match(regex) }
        end
      end

      filtered_changes = filtered_changes.reject do | resource |
        @options['ignore_changes'].detect { |regex| (resource.resource_name.to_s + '[' + resource.name + ']').match(regex) }
      end

      if @options['suppress_empty'] && filtered_changes.empty? then
        Chef::Log.info "email_reports[" + report_name.to_s + "] saw no interesting changes, suppressing email"
        return
      end


      #------
      # Locate template
      #------

      # First find cookbook object
      template_cookbook = run_context.cookbook_collection[@options['template_cookbook']]

      # Chef::Log.info("template cookbook dump: #{template_cookbook.inspect()}")
      template_filename = template_cookbook.preferred_filename_on_disk_location(node, :templates, @options['template_source'])
      template = IO.read(template_filename)

      #------
      # Render Template
      #------

      context = {
        :node => node,
        :run_status => run_status,
        :filtered_changes => filtered_changes,
      }

      body = Erubis::Eruby.new(template).evaluate(context)
      # Chef::Log.info("body: #{body}")

      #------
      # Send Email
      #------

      mail = {}
      mail[:to] = @options['recipients'].join(', ')
      mail[:from] = macro_eval(@options['sender'])
      mail[:subject] = macro_eval(@options['subject']);

      if @options[:treat_as_html] then
        mail[:html_body] = body
      else
        mail[:body] = body
      end
      
      Pony.mail(mail)
      Chef::Log.info("email_reports[" + report_name.to_s + "] sent a message to #{mail[:to]}, subject #{mail[:subject]}")

    end

  end
end

