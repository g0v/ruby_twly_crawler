#!/usr/bin/env ruby

require 'open-uri'
require 'nokogiri'
require 'json'
require 'mechanize'
require 'fileutils'
require 'date'
require 'logger'
require 'colorize'

$stdout.sync = true
Dir.chdir(File.dirname(__FILE__))

module Logging
  def logger
    Logging.logger
  end

  def self.logger
    @logger ||= Logger.new('logs/ly_info.log')
  end
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

def write_json(data, file=nil)
  unless file
    file = 'data/ly_info.json'
  end
  File.write(file, JSON.pretty_generate(data))
end

def init_mechanize
  agent = Mechanize.new
end

def get_html(agent, url)
  Logging.logger.info url.to_s
  page = agent.get(url)
  return page.parser
end

def merge_url(url)
  unless url.start_with?('https://www.ly.gov.tw')
    url = URI::join('https://www.ly.gov.tw/', url)
  end
  return url
end

def convert_roc_date(string)
  date_array = string.strip.split(/年|月|日/).map { |s| s.to_i }
  date_array[0] += 1911
  return Date.new(*date_array)
end

def get_ad_url(ad)
  ad_pages = {
    '3' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=144',
    '4' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=143',
    '5' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=142',
    '6' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=141',
    '7' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=140',
    '8' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=139',
    '9' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=37103',
    '10' => 'https://www.ly.gov.tw/Pages/List.aspx?nodeid=109'
  }
  return ad_pages[ad.to_s]
end

def get_profile_urls(html)
  profile_nodes = html.xpath('//section[@id="six-legislatorListBox"]//div[@class="thumbnail six-legislatorAvatar"]//a[@data-toggle="tooltip"]')
  profile_urls = profile_nodes.map { |n| merge_url(n.attr('href')) }
end

def parse_ad_page(agent, ad)
  url = get_ad_url(ad)
  if url
    Logging.logger.info "第#{ad}屆"
    html = get_html(agent, url)
    profile_urls = get_profile_urls(html)
    print '.'.green
    return profile_urls
  else
    return []
  end
end

def parse_profile_page(agent, url)
  legislator = {}
  legislator[:in_office] = true
  legislator[:links] = { ly: url }
  html = get_html(agent, url)
  info_node = html.xpath('//article[@class="content"]/section[@id="six-legislatorBox"]').first
  legislator[:name] = normalize_name(info_node.xpath('//div[@class="legislatorname"]').first.text)
  Logging.logger.info legislator[:name]
  img = info_node.xpath('//img[@class="img-responsive img-thumbnail"]').first.attr('src')
  if img.start_with?('/Images')
    legislator[:image] = merge_url(img)
  end
  left_node = info_node.xpath('//div[@class="info-left"]').first
  left_node.xpath('ul/li').each do |node|
    node_texts = node.text.split('：')
    case node_texts.first
    when '英文姓名'
      legislator[:english_name] = node_texts[1].gsub(/\s+/, ' ')
    when '屆別'
      legislator[:ad] = node_texts[1].gsub('第 ', '').gsub(' 屆', '').to_i
    when '性別'
      legislator[:gender] = node_texts[1]
    when '黨籍'
      legislator[:party] = node_texts[1]
    when '黨(政)團'
      legislator[:caucus] = node_texts[1]
    when '選區'
      legislator[:constituency] = node_texts[1]
    when '委員會'
      legislator[:committees] = []
      committee_nodes = node.xpath('ul/li')
      regex = /第([\d]{1,2})屆第([\d]{1,2})會期：[\s]*([\S&&[^\(]&&[^\)]]+)[\s]*(\(召集委員\))?/
      committee_nodes.each do |c|
        begin
          matches = c.text.match(regex)
          if matches
            _, ad, session, name, chair = *matches
            if chair
              chair = true
            else
              chair = false
            end
            committee = {
              ad: ad,
              session: session,
              chair: chair,
              name: name
            }
          else
            Logging.logger.error c.text
            print '.'.red
          end
        rescue
          Logging.logger.error c.text
          print '.'.red
        end
        legislator[:committees] << committee
      end
    when '到職日期'
      legislator[:term_start] = convert_roc_date(node_texts[1])
    end
  end

  right_node = info_node.xpath('//div[@class="col-sm-8 info-right"]').first
  h4_nodes = right_node.xpath('h4[@class="title"]')
  ul_nodes = right_node.xpath('ul')
  contacts = {}
  [*0..(h4_nodes.length - 1)].each do |n|
    case h4_nodes[n].text
    when '學歷'
      legislator[:education] = ul_nodes[n].xpath('li').map { |n| n.text }
    when '經歷'
      legislator[:experience] = ul_nodes[n].xpath('li').map { |n| n.text }
    when '電話'
      office_phones = ul_nodes[n].xpath('li').map { |n| n.text.split('：') }
      office_phones.each do |p|
        unless contacts.keys.include?(p[0])
          contacts[p[0]] = {}
        end
        contacts[p[0]][:phone] = p[1]
      end
    when '傳真'
      office_faxes = ul_nodes[n].xpath('li').map { |n| n.text.split('：') }
      office_faxes.each do |f|
        unless contacts.keys.include?(f[0])
          contacts[f[0]] = {}
        end
        contacts[f[0]][:fax] = f[1]
      end
    when '通訊處'
      office_addesses = ul_nodes[n].xpath('li').map { |n| n.text.split('：') }
      office_addesses.each do |a|
        unless contacts.keys.include?(a[0])
          contacts[a[0]] = {}
        end
        contacts[a[0]][:address] = a[1]
      end
    when '備註'
      # legislator[:remark] = ul_nodes[n].xpath('li').map { |n| n.text }
      if ul_nodes[n].text.match(/生效日期：/)
        legislator[:term_end] = {}
        legislator[:term_end][:reason] = ul_nodes[n].xpath('li')[0].text
        date_string = ul_nodes[n].xpath('li')[1].text.split('：').last
        legislator[:term_end][:date] = convert_roc_date(date_string)
        if ul_nodes[n].xpath('li')[2] && ul_nodes[n].xpath('li')[2].text.match(/遞補委員：/)
          legislator[:term_end][:replacement] = ul_nodes[n].xpath('li')[2].text.gsub('遞補委員：', '')
        end
        legislator[:in_office] = false
      end
    end
  end
  unless contacts.empty?
    legislator[:contacts] = []
    contacts.keys.each do |key|
      contacts[key][:name] = key
      legislator[:contacts] << contacts[key]
    end
  end
  print '.'.green
  return legislator
end

def main
  agent = init_mechanize
  legislators = []
  exist_ads = [*3..9].map { |i| i.to_s }
  if ARGV[0]
    ads = [ARGV[0]]
  else
    ads = exist_ads
  end
  ads.each do |ad|
    profile_urls = parse_ad_page(agent, ad)
    sleep(rand(3))
    profile_urls.each do |url|
      sleep(rand(3))
      legislator = parse_profile_page(agent, url)
      legislators << legislator
    end
  end
  write_json(legislators)
  puts "\n"
end

main()
