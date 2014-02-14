require "hashie/extensions/key_conversion"

class Hash
  include Hashie::Extensions::SymbolizeKeys
end