## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# frozen_string_literal: true
# encoding: utf-8
require 'rack'
require 'json'
require 'faraday'
require 'tempfile'
require 'fileutils'
require 'net/http/post/multipart'
require 'tng/gtk/utils/logger'
require_relative './utils'

class Uploader
  attr_accessor :app
  LOGGER=Tng::Gtk::Utils::Logger
  LOGGED_COMPONENT=self.name
  @@began_at = Time.now.utc
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'START', message:"Started at #{@@began_at}")  
  include Utils
  def call(env)
    msg = '#'+__method__.to_s
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"entered with env=#{env}")  

    request = Rack::Request.new(env)
    bad_request('No files to upload') unless request.form_data?

    Tempfile.open do |tempfile|
      tempfile.binmode
      tempfile.write request.body.read
      tempfile.flush
      LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Tempfilename #{tempfile.path} will contain #{tempfile.size} bytes")  
      tempfile.rewind
      begin
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Calling #{env['5gtango.sink_path']}")  
        conn = Faraday.new(url: env['5gtango.sink_path']) do |faraday|
          faraday.request :multipart
          #faraday.response :logger
          faraday.adapter :net_http
        end
        resp = conn.post do |req|
          req.headers['Content-Type'] = request.content_type
          req.headers['Content-Encoding'] = 'gzip'
          req.headers['Content-Length'] = tempfile.size.to_s
          req.headers['Accept'] = 'application/json'
          req.body = Faraday::UploadIO.new(tempfile, 'octet/stream')
        end
        return respond(200, {'Content-Type'=>'application/json'}, resp.body)
      rescue => e
        LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"Exception caught at POSTing body: #{e.message}\n#{e.backtrace.join("\n\t")}")  
        return respond(400, {'Content-Type'=>'application/json'}, {error: "Exception caught at POSTing body: #{e.message}\n#{e.backtrace.join("\n\t")}"})
      end
    end
    LOGGER.debug(component:LOGGED_COMPONENT, operation:msg, message:"A problem occurred with POSTing the body")  
    bad_request('A problem occurred with POSTing the body')
  end
  LOGGER.info(component:LOGGED_COMPONENT, operation:'initializing', start_stop: 'STOP', message:"Ended at #{Time.now.utc}", time_elapsed:"#{Time.now.utc-@@began_at}")
end
