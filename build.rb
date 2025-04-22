#!/usr/bin/env ruby

require 'yaml'
require 'erb'
require 'ostruct'
require 'json'
require 'csv'

base = File.dirname(__FILE__)

require File.expand_path('yaml_deep_merge', base)

config = File.expand_path('raisenow.yml', base)
# WARN: this is needed by ruby 3 but it will break the language
# setting of the tamaro widget, wtf?
# data = YAML.unsafe_load(File.read(config))
data = YAML.load(File.read(config))

# read the pricing sheet
sheet = File.expand_path('pricing.csv', base)
csv = CSV.read(sheet, headers: true)
puts  "Processing pricing sheet: #{csv.count} lines"
pricing = csv.reduce({}) do |aggr, row|
  form = (row["Formular"] || "default").strip
  variant = (row["Variante"] || ".").strip
  caption = (row["Beschriftung"] || ".").strip
  aggr[form] ||= {}
  aggr[form][variant] ||= []
  aggr[form][variant] << {
    chf: row["CHF"],
    eur: row["EUR"],
    usd: row["USD"],
    caption: caption
  }
  aggr
end

# predefined currencies to support
CURRENCIES = [:chf, :eur, :usd]

# predefined conditional clauses, which are referenced in column "Variante"
CONDITIONALS = {
  "grasspaper" => "paymentForm(stored_customer_certificate) == grasspaper",
  "digital"    => "paymentForm(stored_customer_certificate) == digital",
  "none"       => "paymentForm(stored_customer_certificate) == none",
  # rnwPatenschaftenAuswahl
  "einmalig"   => "paymentType() == onetime",
  "monatlich"  => "paymentType() == recurring and recurringInterval() == monthly",
  "jährlich"   => "paymentType() == recurring and recurringInterval() == yearly"
}

def compile_amounts(variants)
  return if variants.nil?
  if variants.count == 1
    variant = variants.values.first
    CURRENCIES.map do |currency|
      { "if" => "currency() == #{currency}",
        "then" => variant.map { |v| v[currency].to_f }.sort }
    end
  else
    variants.map do |kv|
      variant_name, variant = kv
      CURRENCIES.map do |currency|
        { "if" => "currency() == #{currency} and #{CONDITIONALS[variant_name]}",
          "then" => variant.map { |v| v[currency].to_f }.sort }
      end
    end.flatten
  end
end

def compile_minimumCustomAmount(amounts)
  amounts.map do |amount|
    amount.dup.tap do |x|
      x["then"] = [x["then"].first]
    end
  end
end

def compile_amountDescriptions(variants)
  [].tap do |result|
    variants.each do |kv|
      variant_name, amounts = kv
      CURRENCIES.each do |currency|
        amounts.each do |amount|
          next if amount[:caption] == '.'
          result << {
            "if" => ["currency() == #{currency}",
                     "amount() == #{amount[currency]}",
                     variant_name != '.' ? CONDITIONALS[variant_name] : nil].compact.join(" and "),
            "then" => ["#{amount[:caption]}"]
          }
        end
      end
    end
  end
end

# walk tamaro forms and update amounts and other properties
# based on sheet
form_names = data["tamaro"].keys
form_names.each do |form_name|
  form = data["tamaro"][form_name]
  variants= pricing[form_name]
  if variants.nil?
    warn "Missing pricing for #{form_name}"
  else
    puts "Found #{variants.count} variants for #{form_name}"
    amounts = compile_amounts(variants)
    form["amounts"] = amounts
    # form["minimumCustomAmount"] = compile_minimumCustomAmount(amounts)
    form["translations"]["de"]["amount_descriptions"] = compile_amountDescriptions(variants)
    data["tamaro"][form_name] = form
  end
end

# dump data for inspection
File.open('raisenow.expanded.yml', 'w') do |file|
  file.write(data.to_yaml)
end

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
