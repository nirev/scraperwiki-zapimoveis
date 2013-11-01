#!/usr/bin/ruby
# vim: set ts=4 sw=4:

require 'rubygems'
require 'active_support/time'
require 'nokogiri'
require 'open-uri'
require 'scraperwiki'
require 'slop'

LIMIT_DATE = Date.today - 1.days
BASE_URL = 'http://www.zap.com.br/imoveis/sao-paulo+sao-paulo+%s/%s-padrao/aluguel/?tipobusca=rapida&rangeValor=0-%s&foto=1&ord=dataatualizacao'

def clean_tables
	ScraperWiki::sqliteexecute("DROP TABLE IF EXISTS `swdata`")
	ScraperWiki::sqliteexecute("CREATE TABLE `swdata` (`url` text, `data` text, `total` integer, `bairro` text, `rua` text, `area` text, `dorms` text, `aluguel` text, `cond` text, `iptu` text)")
end

def get_neighborhood_url name, type, price
	BASE_URL % [name, type, price]
end

def crawl url, neighborhood, price_limit
	doc = Nokogiri::HTML(open(url), nil, 'ISO-8859-1')

	doc.css('.itemOf').each do |item|
		date_str = item.css('div.itemData span').text.strip.split.last
		date = Date.strptime date_str, '%d/%m/%Y'
		break if date < LIMIT_DATE

		data = {}
		data['url'] = item.at_css('div.full a')['href']
		data['bairro'] = neighborhood
		data['data'] = date_str

		itempage = Nokogiri::HTML(open(data['url']), nil, 'ISO-8859-1')
		data['rua'] = itempage.at_css('span.street-address').text if itempage.at_css('span.street-address')
		itempage.css('ul.fc-detalhes li').each do |attr|
			case attr.css('span').first
				when /dormit.rios/
					data['dorms'] = attr.css('span').last.text.split.first
				when /.rea.*til/
					data['area'] = attr.css('span').last.text.gsub(/\s+/, "")
				when /condom.*/
					data['cond'] = attr.css('span').last.text.strip
				when /IPTU.*/
					data['iptu'] = attr.css('span').last.text.strip
				when /pre.* de aluguel.*/
					data['aluguel'] = attr.css('span').last.text.strip
			end
			data['total'] = 0
			['aluguel', 'cond', 'iptu'].each {|x| data['total'] += data[x].split.last.gsub('.','').to_i if data[x]}
		end

		puts data if (data['total'] < price_limit)
		ScraperWiki::save_sqlite(['url'], data) if (data['total'] < price_limit)
	end
end


opts = Slop.new(arguments: true) do
    on :t, :type=, "Type: casa or apartmento", as: String, required: true, :match => /^(casa|apartamento)$/
    on :n, :neighborhoods=, "List of neighborhoods" ,as: Array, required: true
    on :p, :price=, "Maximum price", as: Integer, required: true
end

begin
    opts.parse
rescue Exception => e
    puts "Error: #{e.message}\n"
    puts opts.help
	exit 1
end

type = opts[:type]
price = opts[:price]
neighborhoods = opts[:neighborhoods]

#bairros = [
#	'vl-mariana',
#	'vl-madalena',
#	'saude',
#	'jardins',
#	'paraiso',
#	'vl-clementino',
#	'pc-da-arvore',
#	'perdizes',
#	'pinheiros',
#	'sumare',
#	'sumarezinho'
#]

clean_tables

neighborhoods.each do |n|
	url = get_neighborhood_url(n, type, price)
	crawl url, n, price
end

