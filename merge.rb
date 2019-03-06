#!/usr/bin/env ruby

require 'json'
require 'colorize'
require 'logger'

$stdout.sync = true
Dir.chdir(File.dirname(__FILE__))

module Logging
  def logger
    Logging.logger
  end

  def self.logger
    @logger ||= Logger.new('logs/merge.log')
  end
end

def write_json(data, file=nil)
  unless file
    file = 'data/merged.json'
  end
  File.write(file, JSON.pretty_generate(data))
end

def read_json(file)
  JSON.parse(File.read(file))
end

def read_legislators_uid_json
  read_json('data/legislators_uid.json')
end

def read_npl_ly_json
  read_json('data/npl_ly.json')
end

def read_ly_info_json
  read_json('data/ly_info.json')
end

def find_legislator(legislators, names, ad, uid=nil)
  possible_legislators = []
  if uid
    # 第一屆陳錦濤一位來自印尼，一位來自厄瓜多，只能用uid辨識。
    possible_legislators = legislators.select { |l| l['uid'] == uid }
  else
    legislators.each do |l|
      if names.include?(l['name']) && l['ad'].to_i == ad
        possible_legislators << l
      elsif l['former_names']
        if (l['former_names'] & names).length > 1 && l['ad'].to_i == ad
          possible_legislators << l
        end
      end
    end
  end
  if possible_legislators.length == 1
    return possible_legislators.first
  elsif possible_legislators.length == 0
    return nil
  else
    puts "duplicate legislator #{names.first}, #{ad}"
    return possible_legislators.first
  end
end

def find_uid(legislators, name, ad)
  legislator = nil
  legislators.each do |l|
    if l['name'] == name && l['ads'].include?(ad)
      legislator = l
      break
    elsif l['former_names']
      if l['former_names'].include?(name) && l['ads'].include?(ad)
        legislator = l
        break
      end
    end
  end
  return legislator
end

def check_no_uid(uids, npl_ly_infos)
  result = true
  npl_ly_infos.each do |info|
    legislator = find_uid(uids, info['name'], info['ad'])
    unless legislator
      puts "第#{info['ad']}屆立法委員#{info['name']}找不到UID"
      puts "到職日期：#{info['term_start']}"
      puts "#{info['links']['npl']}"
      result = false
    end
  end
  return result
end

def merge_legislator(uid, npl_ly_infos, ly_infos)
  legislator = {}
  Logging.logger.info "#{uid['uid']} #{uid['name']}"
  legislator[:name] = uid['name']
  legislator[:uid] = uid['uid']
  legislator[:former_names] = uid['former_names']
  legislator[:ads] = uid['ads']
  legislator[:each_term] = []
  uid['ads'].each do |ad|
    if uid['name'] == '陳錦濤' && uid['ads'] == [1]
      npl_ly_info = find_legislator(npl_ly_infos, uid['identifiers'], ad, uid['uid'])
    else
      npl_ly_info = find_legislator(npl_ly_infos, uid['identifiers'], ad)
    end
    ly_info = find_legislator(ly_infos, uid['identifiers'], ad)
    if ly_info
      npl_ly_info['links']['ly'] = ly_info['links']['ly'] if ly_info['links']['ly']
      npl_ly_info['term_end'] = ly_info['term_end'] if ly_info['term_end']
      npl_ly_info['caucus'] = ly_info['caucus'] if ly_info['caucus']
      npl_ly_info['contacts'] = ly_info['contacts'] if ly_info['contacts']
      if npl_ly_info['former_names']
        legislator[:former_names] = (legislator[:former_names] | npl_ly_info['former_names'])
        npl_ly_info.delete('former_names')
      end
    end
    legislator[:each_term] << npl_ly_info if npl_ly_info
  end
  print '.'.green
  return legislator
end

def find_legislator_from_ly_info(names, term, ly_infos)
  possibles = ly_infos.select { |l| names.include?(l['name']) && l['ad'] == term['ad'] }
  if possibles.length == 1
    return possible[0]
  elsif possibles.length == 0
    puts "ly2npl cannot find legislator at ad: #{term['ad']} named: #{names[0]}"
  else
    puts "ly2npl find duplicate name in #{names} at ad: #{term['ad']}"
    possible = possibles.select { |l| l['party'] == term['party'] && l['gender'] == term['gender'] }
    if possible.length == 1
      return possible.first
    else
      puts 'ly2npl still can not find only one legislator from possible list!!'
    end
  end
end

def find_legislator_from_npl(legislator, npl_ly_infos)
  possibles = npl_ly_infos.select { |l| l['name'] == legislator['name'] && l['ad'] == legislator['ad'] }
  if possibles.length == 1
    return possible[0]
  elsif possibles.length == 0
    puts "npl2ly cannot find legislator at ad: #{legislator['ad']} named: #{legislator['name']}"
  else
    puts "npl2ly find duplicate name #{legislator['name']} at ad: #{legislator['ad']}"
    possible = possibles.select { |l| l['party'] == legislator['party'] && l['gender'] == legislator['gender'] }
    if possible.length == 1
      return possible.first
    else
      puts 'npl2ly still can not find only one legislator from possible list!!'
    end
  end
end

def complement(ly_info, npl_ly_info)
  ly_info.keys.each do |k|
    unless npl_ly_info.keys.include? k
      npl_ly_info[k] = ly_info[k]
    end
  end
  npl_ly_info['constituency'] = ly_info['constituency']
  if npl_ly_info['ad'] != 1
    npl_ly_info['experience'] = ly_info['experience']
  end
  return npl_ly_info
end

def conflict(compare, base, f)
  ["gender", "in_office"].each do |k|
    if compare.keys.include?(k) && base.keys.include?(k)
      if compare[k] != base[k]
      end
    end
  end
end

def main
  uids = read_legislators_uid_json()
  npl_ly_infos = read_npl_ly_json()
  ly_infos = read_ly_info_json()
  unless check_no_uid(uids, npl_ly_infos)
    raise 'some legislator not have uid!'
  end
  legislators = []
  uids.each do |uid|
    legislator = merge_legislator(uid, npl_ly_infos, ly_infos)
    legislators << legislator
  end
  write_json(legislators, 'data/merged.json')
  puts "\n"
end

main()

