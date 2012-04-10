#!/usr/bin/env ruby

require 'yaml'
require_relative './lib/config'
require_relative './lib/base'

SpamFilter.configure do |config|
  config.spam_corpus          = 'corpus/spam_corpus'
  config.ham_corpus           = 'corpus/ham_corpus'
  config.spam_test            = 'corpus/spam_test'
  config.ham_test             = 'corpus/ham_test'
  config.spamicities_file     = 'spamicities.yml'
  config.top_tokens_list_size = 27
  config.spam_threshold       = 0.9
  config.ham_token_multiplier = 1
end

SpamFilter.run
