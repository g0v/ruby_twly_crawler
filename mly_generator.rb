#!/usr/bin/env ruby

require 'json'
require 'digest'
require 'colorize'

$stdout.sync = true
Dir.chdir(File.dirname(__FILE__))

module Logging
  def logger
    Logging.logger
  end

  def self.logger
    @logger ||= Logger.new('logs/mly.log')
  end
end

def write_json(data, file=nil)
  unless file
    file = 'data/mly.json'
  end
  File.write(file, JSON.pretty_generate(data))
end

def write_csv(data, file=nil)
  unless file
    file = 'data/mly.csv'
  end
  File.write(file, data.join("\n"))
end

def read_json(file)
  JSON.parse(File.read(file))
end

def md5_hash(string)
  md5 = Digest::MD5.new
  md5.update string
  return md5.hexdigest
end

def party_code(party)
  case party
  when '中國國民黨'
    code = 'KMT'
  when '民主進步黨'
    code = 'DPP'
  when '台灣團結聯盟'
    code = 'TSU'
  when '無黨團結聯盟'
    code = 'NSU'
  when '親民黨'
    code = 'PFP'
  when '新黨'
    code = 'NP'
  when '建國黨'
    code = 'TIP'
  when '超黨派問政聯盟'
    code = 'CPU'
  when '民主聯盟'
    code = 'DU'
  when '時代力量'
    code = 'NPP'
  when '民國黨'
    code = 'MKT'
  when '台灣基進'
    code = 'TSP'
  when '台灣民眾黨'
    code = 'TPP'
  when /無(黨籍)?/
    code = nil
  when '其他'
  else
    code = nil
  end
  return code
end

def city_code(city)
  # ISO-3166-2:TW
  city = city.gsub('台', '臺')
  case city
  when '新北市'
    code = 'NWT'
  when '臺北市'
    code = 'TPE'
  when '臺中市'
    code = 'TXG'
  when '臺南市'
    code = 'TNN'
  when '高雄市'
    code = 'KHH'
  when '基隆市'
    code = 'KEE'
  when '新竹市'
    code = 'HSZ'
  when '嘉義市'
    code = 'CYI'
  when '桃園縣'
    code = 'TAO'
  when '桃園市'
    code = 'TAO'
  when '新竹縣'
    code = 'HSQ'
  when '苗栗縣'
    code = 'MIA'
  when '彰化縣'
    code = 'CHA'
  when '南投縣'
    code = 'NAN'
  when '雲林縣'
    code = 'YUN'
  when '嘉義縣'
    code = 'CYQ'
  when '屏東縣'
    code = 'PIF'
  when '宜蘭縣'
    code = 'ILA'
  when '花蓮縣'
    code = 'HUA'
  when '臺東縣'
    code = 'TTT'
  when '澎湖縣'
    code = 'PEN'
  when '高雄縣'
    code = 'KHQ'
  when '臺南縣'
    code = 'TNQ'
  when '臺北縣'
    code = 'TPQ'
  when '臺中縣'
    code = 'TXQ'
  when '金門縣'
    code = 'KIN'
  when '連江縣'
    code = 'LIE'
  else
    code = nil
  end
end

def zh_num_to_i(string)
  if string.match(/^\d+$/)
    string = string.to_i
  elsif string.match(/^[一二三四五六七八九十]+$/)
    if string.match(/^十/)
      string = '一' + string
    end
    if string.match(/十$/)
      string = string + '零'
    end
    # 不考慮「百」
    string = string.gsub('十', '')
    chinese = "零一二三四五六七八九"
    arabic = "0123456789"
    string = string.tr(chinese, arabic).to_i
  end
  return string
end

def parse_constituency(constituency)
  constituency = constituency.gsub('(增額)', '')
  case constituency
  when /^.*(市|縣)$/
    code = [city_code(constituency), 0]
  when /(.*(?:市|縣))(?:第(\S+))?選舉區/
    if $2
      area = zh_num_to_i($2)
    else
      area = 0
    end
    code = [city_code($1), area]
  when '平地原住民'
    code = ['aborigine', 'lowland']
  when '山地原住民'
    code = ['aborigine', 'highland']
  when '全國不分區'
    code = ['proportional']
  when /僑居國外國民|僑選/
    code = ['foreign']
  end
  return code
end

def main
  ad = ARGV[0].to_i
  type = ARGV[1].to_s
  legislators = []
  legislators_csv = ["id, name"]
  merged_legislators = read_json('data/merged.json')
  merged_legislators.each do |l|
    l['each_term'].each do |term|
      if term['ad'].to_i == ad
        term['uid'] = l['uid']
        term['identifiers'] = l['identifiers']
        term['ads'] = l['ads']
        term['former_names'] = l['former_names']
        term['party'] = party_code(term['party']) if term['party']
        term['elected_party'] = party_code(term['elected_party']) if term['elected_party']
        term['caucus'] = party_code(term['caucus']) if term['caucus']
        term['constituency'] = parse_constituency(term['constituency'])
        key = md5_hash("MLY/#{l['name']}")
        term['avatar'] = "http://avatars.io/50a65bb26e293122b0000073/#{key}"
        print '.'.green
        legislators << term
        legislators_csv << "#{term['uid']}, \"#{l['name']}\""
      end
    end
  end
  write_json(legislators, "data/mly-#{ad}.json")
  if type == "csv"
    write_csv(legislators_csv, "data/mly-#{ad}.csv")
  end
  puts "\n"
end

main()

