#!/usr/bin/env ruby
require 'optparse'
require_relative './lib/base'

optparse = OptionParser.new do |opts|

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
  
  opts.on('--train-spam', '--train-spam FILE(S)', 'Add message(s) to the spam training corpus') do |spam_path|
    sf = SpamFilter.new
    Dir[spam_path].each do |spam|
      text = sf.read(spam)
      sf.train(text, :spam)
    end
    sf.save
    puts 'Message(s) added to spam training corpus.'
  end

  opts.on('--train-ham', '--train-ham FILE', 'Add a message to the ham training corpus') do |ham_path|
    sf = SpamFilter.new
    Dir[ham_path].each do |ham|
      text = sf.read(ham)
      sf.train(text, :ham)
    end
    sf.save
    puts 'Message(s) added to ham training corpus.'
  end

  opts.on('--clear-db', '--clear-database', 'Deletes all data from training corpus database') do
    sf = SpamFilter.new
    sf.clear_database
    sf.save
    puts 'Training corpus database cleared.'
  end
end

optparse.parse!
