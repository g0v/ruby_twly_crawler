#!/usr/bin/env ruby

require 'json'
require 'colorize'

$stdout.sync = true
Dir.chdir(File.dirname(__FILE__))

def write_json(data, file=nil)
  unless file
    file = 'data/legislators_uid.json'
  end
  File.write(file, JSON.pretty_generate(data))
end

def read_json(file)
  JSON.parse(File.read(file))
end

def normalize_name(name)
  name = name.strip
  name = name.gsub(/[。˙・･•．\.]/, '‧')
  name = name.gsub(/[\(\)（）]/, '')
  name = name.gsub(/[　\s]+/, ' ')
  regex = /[a-zA-Z]+([‧\s][a-zA-Z]+)*/
  if name.match(regex)
    pinyin_name = name.match(regex).to_a.first
    name = name.gsub(pinyin_name, '').rstrip + " #{pinyin_name}"
  end
  # name = name.capitalize
  return name
end

def find_uid(uids, uid)
  legislator = nil
  uids.each do |l|
    if l[:uid] == uid
      legislator = l
    end
  end
  return legislator
end

def main()
  legislators = read_json('original_data/merged.json')
  uids = []
  uid_list = []
  legislators.each do |l|
    legislator = {}
    legislator[:ads] = []
    l['each_term'].each do |term|
      legislator[:ads] << term['ad']
      legislator[:gender] = term['gender']
    end
    legislator[:name] = normalize_name(l['name'])
    legislator[:former_names] = l['former_names'].map { |n| normalize_name(n) }.reject { |n| n.empty? }
    legislator[:identifiers] = ([legislator[:name]] | legislator[:former_names]).reject { |n| n.empty? }
    legislator[:uid] = l['uid'].to_i
    uid_list << l['uid'].to_i
    uids << legislator
  end
  legislators = read_json('original_data/merged_uid_by_ourself.json')
  legislators.each do |l|
    legislator = find_uid(uids, l['uid'].to_i)
    unless legislator
      legislator = {}
      legislator[:ads] = l['ads']
      legislator[:name] = normalize_name(l['name'])
      legislator[:former_names] = [l['former_names']].map { |n| normalize_name(n) }.reject { |n| n.empty? }
      legislator[:identifiers] = ([legislator[:name]] | legislator[:former_names]).reject { |n| n.empty? }
      legislator[:uid] = l['uid']
      legislator[:gender] = l['gender']
      uid_list << l['uid'].to_i
      uids << legislator
      print '.'.green
    end
  end
  additionals = read_json('additional/additionals.json')
  additionals.each do |l|
    find_in_uids = false
    uids.each do |uid|
      if uid[:uid] == l['uid'].to_i
        uid[:ads] = (uid[:ads] | l['ads']).sort
        find_in_uids = true
        break
      end
    end
    unless find_in_uids
      uids << l
    end
    print '.'.green
  end
  write_json(uids, 'data/legislators_uid.json')
  puts "\n"
end

main()
