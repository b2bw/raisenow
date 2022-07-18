#!/usr/bin/env ruby

require 'yaml'

class Hash
  def deep_merge!(other_hash)
    merge!(other_hash) do |_, this_val, other_val|
      if this_val.is_a?(Hash) && other_val.is_a?(Hash)
        this_val.deep_merge(other_val)
      else
        other_val
      end
    end
  end

  def walk(&bloc)
    reduce({}) do |aggregator, entry|
      key, val = entry
      nval = val.class.method_defined?(:walk) ? val.walk(&bloc) : val
      aggregator.merge(key => nval).tap do |result|
        yield(result, key) if block_given?
      end
    end
  end
end

class Array
  def walk(&bloc)
    map { |e| e.class.method_defined?(:walk) ? e.walk(&bloc) : e }
  end
end

module YamlDeepMerge
  def load(*args)
    super(*args).walk do |h, k|
      k == '<<<' &&
        h.deep_merge!(h.delete(k))
    end
  end
end

module YAML
  class << self
    prepend YamlDeepMerge
  end
end

puts YAML.dump(YAML.load(ARGF.read)) if $PROGRAM_NAME == __FILE__
