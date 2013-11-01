#!/usr/bin/ruby
# vim: set ts=4 sw=4

require 'slop'

opts = Slop.parse(arguments: true) do
    on :tipo=, as: String, required: true
    on :bairros=, as: Array, required: true
    on :price=, as: Integer, required: true
end

