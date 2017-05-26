#!/usr/bin/env ruby

require 'json'
require_relative 'dicom'

@mode = :brief

def dump_element(e)
  tg = e.tag_group
  if tg.is_a?(String)
    tg = tg.unpack('v')[0]
  end
  h = {"tag" => sprintf("%04x:%04x", tg, e.tag_elem)}

  if e.respond_to?(:tag) and e.tag.is_a?(Symbol)
    h['desc'] = e.tag.to_s.gsub(/^tags_/, '')
  end
  
  if @mode != :brief
    h['vr'] = e.vr if e.respond_to?(:vr)
  end

  unless e.value.nil?
    vstr = if e.value.size > 1000
             "(#{e.value.size} bytes)"
           else
             begin
               e.value.encode('UTF-8')
             rescue Encoding::UndefinedConversionError => err
               e.value.bytes.map { |x| sprintf("%02X", x) }.join(" ")
             end
           end
    h['value'] = vstr
  end

  if e.respond_to?(:items) and e.items
    h['items'] = dump_elements(e.items)
  end

  if @mode == :brief
    h.delete('tag') if h['tag'] == 'fffe:e000' # start-of-seq
    h = nil if h['tag'] == 'fffe:e00d' or h['tag'] == 'fffe:e0dd' # end-of-item or end-of-seq    
  end

  h
end

def dump_elements(ee)
  ee.map { |e| dump_element(e) }.delete_if { |x| x.nil? }
end

def dump_file(fn)
  d = Dicom.from_file(fn)
  dump_elements(d.elements)
end

ARGV.each { |fn|
  puts JSON.pretty_generate(dump_file(fn))
}
