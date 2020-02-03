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
    @logger ||= Logger.new('logs/npl_ly.log')
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
    file = 'data/npl_ly.json'
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
  unless url.start_with?('https://lis.ly.gov.tw')
    url = URI::join('https://lis.ly.gov.tw/', url)
  end
  return url
end

def get_current_ad(html)
  # 應該不會有多個ad的情形，故只找第一個
  ad = html.xpath('//ul[@id="ball_r"]/li/a[@class="stay"]/text()').first.to_s
  return ad
end

def get_ad_url(html, ad)
  ad_nodes = html.xpath('//ul[@id="ball_r"]/li/a')
  url = nil
  ad_nodes.each do |node|
    if node.text == ad.to_s
      url = merge_url(node.attr('href'))
      break
    end
  end
  return url
end

def get_profile_urls(html)
  profile_nodes = html.xpath('//div[@id="box01"]/table[@class="list01"]//a[starts-with(@href, "/lylegisc")]')
  profile_urls = profile_nodes.map { |n| merge_url(n.attr('href')) }
  return profile_urls
end

def parse_ad_page(agent, ad, url=nil)
  if url == nil
    url = 'https://lis.ly.gov.tw/lylegismc/lylegismemkmout?!!FUNC400'
  end
  Logging.logger.info "第#{ad}屆"
  html = get_html(agent, url)
  current_ad = get_current_ad(html)
  unless current_ad == ad
    url = get_ad_url(html, ad)
    html = get_html(agent, url)
  end
  profile_urls = get_profile_urls(html)
  print '.'.green
  return profile_urls
end

def parse_profile_page(agent, url)
  legislator = {}
  legislator[:in_office] = true
  legislator[:links] = { npl: url }
  html = get_html(agent, url)
  ads = html.xpath('//*[@id="no"]/a').map { |node| node.text.to_i }
  img = html.xpath('//td[@class="content"]//img').first.attr('src')
  unless img.start_with?('/lylegis')
    legislator[:image] = img
  end
  info_nodes = html.xpath('//td[@class="info_bg"]/table/tr')
  info_nodes.each do |node|
    case node.xpath('td[@class="dett01"]').text
    when '姓名'
      name = node.xpath('td[@class="dett02"]').text
      title = '立法委員'
      regex = /([\S]*院長)/
      if name.match(regex)
        _, title = *name.match(regex)
        name = name.gsub(title, '').strip
      end
      legislator[:title] = title
      legislator[:name] = normalize_name(name)
      Logging.logger.info legislator[:name]
    when '姓名參照'
      legislator[:former_names] = [node.xpath('td[@class="dett02"]').text]
    when '英文姓名'
      legislator[:english_name] = node.xpath('td[@class="dett02"]').text.gsub(/\s+/, ' ')
    when '性別'
      legislator[:gender] = node.xpath('td[@class="dett02"]').text
    when '任期'
      legislator[:ad] = node.xpath('td[@class="dett02"]').text.to_i
    when '當選黨籍'
      legislator[:elected_party] = node.xpath('td[@class="dett02"]').text
    when '黨籍'
      legislator[:party] = node.xpath('td[@class="dett02"]').text
    when '選區'
      legislator[:constituency] = node.xpath('td[@class="dett02"]').text
    when '委員會'
      legislator[:committees] = []
      committee_nodes = node.xpath('td[@class="dett02"]//td')
      regex = /第([\d]{1,2})屆第([\d]{1,2})會期[\s]*([\S&&[^\(]&&[^\)]]+)[\s]*(\(召集委員\))?/
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
              ad: ad.to_i,
              session: session.to_i,
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
      date_string = node.xpath('td[@class="dett02"]').text
      legislator[:term_start] = Date.strptime(date_string, "%Y%m%d")
    when '學歷'
      legislator[:education] = node.xpath('td[@class="dett02"]').text.split("\n")
    when '經歷', '簡歷'
      legislator[:experience] = node.xpath('td[@class="dett02"]').text.split("\n")
      if legislator[:name] == '陳錦濤'
        if legislator[:experience].include?('厄瓜多中華總商會正會長')
          legislator[:uid] = 413
        elsif legislator[:experience].include?('印尼勵志社理事長')
          legislator[:uid] = 1768
        end
      end
    when '離職日期'
      date_string = node.xpath('td[@class="dett02"]').text
      legislator[:term_end] = Date.strptime(date_string, "%Y%m%d")
    when '備註'
      legislator[:remark] = node.xpath('td[@class="dett02"]').text.split("\n")
    end
  end
  unless legislator[:elected_party]
    legislator[:elected_party] = legislator[:party]
  end
  print '.'.green
  return legislator
end

def main
  agent = init_mechanize
  legislators = []
  exist_ads = [*1..10].map { |i| i.to_s }
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

