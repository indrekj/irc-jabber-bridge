#!/usr/bin/env ruby
require 'rubygems'
require 'thread'
require 'yaml'
require 'i_jabber'
require 'i_irc'

$config = YAML.load_file(File.dirname(__FILE__) + '/config.yml')
$logger = Logger.new(File.dirname(__FILE__) + '/bridge.log')

class Bridge
  def initialize
    @to_irc = []
    @to_jabber = []
    @lock = Mutex.new
  end

  def shift(to)
    case to
    when :irc
      @lock.synchronize do
        @to_irc.shift
      end
    when :jabber
      @lock.synchronize do
        @to_jabber.shift
      end
    else
      nil
    end
  end

  def add(item, to)
    case to
    when :irc
      @lock.synchronize do
        @to_irc << item
      end
    when :jabber
      @lock.synchronize do
        @to_jabber << item
      end
    else
      nil
    end
  end
end

bridge = Bridge.new

Thread.new do
  begin
    IJabber.start($config[:jabber], bridge)
  rescue Exception => e
    $logger.error e
    $logger.error e.backtrace.join("\n")
  end
end

Thread.new do
  begin
    IIrc.start($config[:irc], bridge)
  rescue Exception => e
    $logger.error e
    $logger.error e.backtrace.join("\n")
  end
end

loop do
  sleep 0.5
end
