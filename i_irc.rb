require "rubygems"
require "isaac/bot"

class IIRC
  def self.start(conf, bridge)
    bot = Isaac::Bot.new do
      configure do |c|
        c.server   = conf[:server]
        c.port     = conf[:port]
        c.ssl      = conf[:ssl]
        c.nick     = conf[:nick]
        c.password = conf[:password]
        c.realname = conf[:name]

        c.environment = :production
        c.verbose     = true
      end

      on :connect do
        join conf[:channel]
      end

      on :channel do 
        bridge.add([nick, message], :jabber)
        $logger.info "Sent a message to the Jabber queue [#{nick}, #{message}]"
      end

      on :private do
        msg nick, "You said: #{message}"
      end
    end

    Thread.new do
      loop do
        sleep 0.1
        
        if item = bridge.shift(:irc)
          user, msg = item
          $logger.info "Received a message from the IRC queue: #{item.inspect}"
          bot.msg(conf[:channel], "[#{user}]: #{msg}")
        end
      end
    end

    bot.start
  end
end
