#!/usr/bin/env ruby
require 'optparse'
require 'set'
require_relative './lib/base'
require_relative './lib/database'
require_relative './lib/parse'


optparse = OptionParser.new do |opts|

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
  
  opts.on('--train-spam', '--train-spam FILE(S)', 'Add message(s) to the spam training corpus') do |spam_path|
    sf = SpamFilter.new
    msg_count = sf.process_messages(spam_path, :spam)
    sf.save
    puts "#{msg_count} message#{'s' if msg_count > 1 } added to spam corpus."
  end

  opts.on('--train-ham', '--train-ham MESSAGE(S)', 'Add message(s) to the ham training corpus') do |ham_path|
    sf = SpamFilter.new
    msg_count = sf.process_messages(ham_path, :ham)
    sf.save
    puts "#{msg_count} message#{'s' if msg_count > 1 } added to ham corpus."
  end

  opts.on('--train', '--train SPAM,HAM', Array, 'Add messages to both spam and ham corpora') do |spam_path, ham_path|
    sf = SpamFilter.new
    msg_count  = sf.process_messages(spam_path, :spam)
    msg_count += sf.process_messages(ham_path, :ham)
    sf.save
    puts "#{msg_count} message#{'s' if msg_count > 1 } added to corpus."
  end

  opts.on('--classify', '--classify MESSAGE(S)', 'Classify message(s) as spam or ham') do |msg_path|
    sf = SpamFilter.new
    counter = 0
    results = []
    Dir[msg_path].each do |msg|
      text = sf.read(msg)
      results << sf.classify(text)
      counter += 1
    end
    spam_count = results.count(:spam)
    ham_count  = results.count(:ham)
    puts "#{counter} message#{'s' if counter > 1 } classified."
    puts "Spam: #{spam_count}, Ham: #{ham_count}"
  end

  opts.on('--clear-db', '--clear-database', 'Deletes all data from training corpus database') do
    SpamFilter.clear_database
    puts 'Training corpus database cleared.'
  end
end

optparse.parse!(ARGV)
