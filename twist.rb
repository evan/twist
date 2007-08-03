#!/usr/bin/env ruby
# Twist - log your system events to twitter
# Copyright 2007 Cloudburst, LLC
# Licensed under the AFL 3. See the included LICENSE file.

require 'yaml'
config = YAML.load_file "/etc/twist.yml"
#--- 
#:sysuser: httpd
#:user: twitter_user
#:password: twitter_password

LOG = "/var/log/auth.log"

puts "already running" or exit if `ps awx | grep ruby | grep twist | wc`.to_i > 2
puts "twittering..."

require "rubygems"
require "twitter"

twit = Twitter::Base.new config[:user], config[:password]
tail = "tail -n 300 #{LOG} | grep -v '(pam_unix)'" # optionally filter some events
tmplog = "/tmp/twist.log"

last_msg = open(tmplog).read if File.exist?(tmplog)
if last_msg
  msgs = `#{tail}`.split("\n")
  if msgs.include?(last_msg)
    msgs = msgs[msgs.index(last_msg)+1..-1] 
    puts "found last message"
  else
    puts "couldn't find last message #{last_msg.inspect}"
  end
  msgs.each do |n|
    last_msg = n
    case n = n.sub(/.*? .*? .*? /, '')
      when /allison sudo/
        if n =~ /allison sudo:  (.*?) :.*PWD=(.*?) ; USER=(.*?) ; COMMAND=(.*)/ 
          n = "#$1->#$3 $ sudo #$4"
        end
      when /Accepted publickey for/
        if n =~ /publickey for (.*?) from (.*?) port (.*?) (.*)/
          n = "#$4 by #$1 from #$2"
        end
    end
    twit.update n
    puts "twittered #{n[0..55]}..."
  end
else
  n = "#{tmplog.inspect} not found at #{Time.now}; restarted?"
  twit.update n
  puts "twittered #{n[0..55]}..."
  last_msg = `#{tail}`.split("\n").last
end

open(tmplog, 'w').write(last_msg)
puts "wrote #{last_msg.inspect} to #{tmplog}"
