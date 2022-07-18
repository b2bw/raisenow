#!/usr/bin/env ruby

require 'yaml'

class Hash
  def deep_merge!(other_hash, &block)
    merge!(other_hash) do |key, this, that|
      if this.is_a?(Hash) && that.is_a?(Hash)
        this.deep_merge!(that, &block)
      elsif block_given?
        yield(key, this, that)
      else
        that
      end
    end
  end

  def walk(&block)
    reduce({}) do |aggregator, entry|
      key, val = entry
      nval = val.class.method_defined?(:walk) ? val.walk(&block) : val
      aggregator.merge(key => nval)
    end.tap { |result| yield(result) if block_given? }
  end
end

class Array
  def walk(&block)
    map { |e| e.class.method_defined?(:walk) ? e.walk(&block) : e }
  end
end

module YamlDeepMerge
  def load(*args)
    super(*args).tap do |result|
      if result.class.method_defined?(:walk)
        result.walk do |h|
          if (x = h.delete('<<<'))
            h.deep_merge!(x) { |_, this, _| this }
          end
        end
      end
    end
  end
end

module YAML
  class << self
    prepend YamlDeepMerge
  end
end

puts YAML.dump(YAML.load(ARGF.read)) if $PROGRAM_NAME == __FILE__
