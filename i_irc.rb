require 'rubygems'
require 'socket'

class IRC
  def initialize(opts = {})
    @server  = opts[:server]
    @port    = opts[:port]
    @nick    = opts[:nick]
    @user    = opts[:user]
    @name    = opts[:name]
    @channel = opts[:channel]
    @bridge  = opts[:bridge]
    @connected = false

    @to_irc_queue = Queue.new
    add_message_listener
  end

  def add_message_listener
    return if defined?(@message_listener)

    @message_listener = Thread.new do
      loop do
        sleep 0.1
        if connected? && msg = @to_irc_queue.pop
          send_raw(msg)
        end
      end
    end
  end

  def connected?
    @connected
  end

  def connect
    Thread.new do
      unless connected?
        begin
          @socket = TCPSocket.open(@server, @port)
          @connected = true
          send "USER #{@user} 0 * :#{@name}"
          send "NICK #{@nick}"
          send "JOIN #{@channel}"
        rescue Exception => e
          $logger.error "Something went wrong while connecting to irc"
          $logger.error e
        end
      end

      sleep 10
    end
  end

  def send(msg)
    @to_irc_queue << msg
  end

  # Use #send instead of this.
  def send_raw(msg)
    $logger.info "To irc: #{msg}"
    @socket.puts msg 
  end

  def say_to_chan(msg)
    send "PRIVMSG #{@channel} :#{msg}"
  end

  def run
    until @socket.eof? do
      msg = @socket.gets

      if msg.match(/^PING :(.*)$/)
        send "PONG #{$~[1]}"
        next
      end

      if msg.match(/^:(.+?)!.+?@.+?\sPRIVMSG.*?(#\w*)\s\:(.+)$/i)
        nick    = $~[1].strip
        channel = $~[2].strip
        text    = $~[3].strip

        if channel == @channel
          @bridge.add([nick, text], :jabber)
          puts "Sent a message to the Jabber queue [#{nick}, #{text}]"
        end
      end
      sleep 0.1
    end
  end

  def quit
    send "PART ##{@channel} :#{@nick}, Hell with this"
    send 'QUIT'
  end
end

class IIrc
  def self.start(config, bridge)
    @bot = IRC.new(
      :server  => config[:server],
      :port    => config[:port],
      :nick    => config[:nick],
      :user    => config[:user],
      :name    => config[:name],
      :channel => config[:channel],
      :bridge  => bridge
    )

    Thread.new do
      sleep 0.1
      
      if @bot.connected? && item = bridge.shift(:irc)
        user, msg = item
        $logger.info "Received a message from the IRC queue: #{item.inspect}"
        @bot.say_to_chan("[#{user}]: #{msg}")
      end
    end

    @bot.connect
    @bot.run
  end
end
