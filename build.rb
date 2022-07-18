#!/usr/bin/env ruby

require 'yaml'
require 'erb'
require 'ostruct'
require 'json'

base = File.dirname(__FILE__)

require File.expand_path('yaml_deep_merge', base)

config = File.expand_path('raisenow.yml', base)
data = YAML.load(File.read(config))

class ErbBinding < OpenStruct
  def get_binding
    return binding()
  end
end

class FalseClass; def to_i; 0 end end
class TrueClass; def to_i; 1 end end

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
            data: data['tamaro'],
            payment_types: {
              %w[onetime] => 'onetime',
              %w[recurring] => 'recurring',
              %w[onetime recurring] => 'any'
            } }
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
