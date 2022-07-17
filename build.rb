#!/usr/bin/env ruby

require 'yaml'
require 'erb'
require 'ostruct'
require 'json'

base = File.dirname(__FILE__)
config = File.expand_path('raisenow.yml', base)
data = YAML.load(File.read(config))

# --- YAML deep merge ---

class Hash
  def deep_merge!(other_hash)
    merge!(other_hash) do |key, this_val, other_val|
      if this_val.is_a?(Hash) && other_val.is_a?(Hash)
        this_val.deep_merge(other_val)
      else
        other_val
      end
    end
  end
end

def walk(x, &bloc)
  case x
  when Array
    x.map { |e| walk(e, &bloc) }
  when Hash
    x.reduce({}) do |a, e|
      key, val = e
      a.merge(key => walk(val, &bloc)).tap do |b|
        bloc.call(b, key) if block_given?
      end
    end
  else
    x
  end
end

data = walk(data) do |h, k|
  k == '<<<' &&
    h.deep_merge!(h.delete(k))
end

# --- YAML deep merge end ---

class ErbBinding < OpenStruct
  def get_binding
    return binding()
  end
end

data['tamaro'].each do |key, _|
  page = File.expand_path(File.join('templates', 'page.html.erb'), base)
  page_target = File.join('public', key + '.html')
  context = { key: key }
  page_content = ERB.new(File.read(page)).result(ErbBinding.new(context).get_binding)
  File.open(page_target, 'w') { |f| f.puts(page_content) }
  puts "Writing #{page_target}"
end

index = File.expand_path(File.join('templates', 'index.html.erb'), base)
index_target = File.join('public', 'index.html')
context = { keys: data['tamaro'].keys,
            data: data['tamaro'] }
index_content = ERB.new(File.read(index)).result(ErbBinding.new(context).get_binding)
puts "Writing #{index_target}"
File.open(index_target, 'w') { |f| f.puts(index_content) }

script = File.expand_path(File.join('templates', 'raisenow.js.erb'), base)
script_target = File.join('public', 'raisenow.js')
context = { forms: JSON.unparse(data['tamaro']),
            terms: data['terms'] }
script_content = ERB.new(File.read(script)).result(ErbBinding.new(context).get_binding)
puts "Writing #{script_target}"
File.open(script_target, 'w') { |f| f.puts(script_content) }
