require 'rubygems'
require 'jabbot'
  
include Jabbot::Handlers
class IJabber
  def self.start(config, bridge)
    config = Jabbot::Config.new(
      :login => config[:id],
      :password => config[:pw],
      :nick => config[:name],
      :server => config[:conference_room].split('@')[1],
      :channel => config[:conference_room].split('@')[0],
      :resource => config[:resource]
    )
    
    @bot = Jabbot::Bot.new(config)

    handler = Jabbot::Handler.new do |msg, params|
      bridge.add([msg.user, msg.text], :irc)
      $logger.info "Sent a message to the IRC queue [#{msg.user}, #{msg.text}]"
    end 
    @bot.handlers[:message] << handler

    Thread.new do
      loop do
        sleep 0.1

        if @bot.connected? && item = bridge.shift(:jabber)
          user, msg = item
          $logger.info "Received a message from the Jabber queue: #{item.inspect}"
          @bot.send_message "[#{user}]: #{msg}"
        end
      end
    end
    
    @bot.connect
  end
end
