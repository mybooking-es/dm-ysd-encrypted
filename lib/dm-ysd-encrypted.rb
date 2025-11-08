require 'dm-core'
require 'dm-ysd-encrypted/crypto'
require 'dm-ysd-encrypted/encrypted'
require 'dm-ysd-encrypted/text_encrypted'

module DataMapper
  class Property  
    autoload :Encrypted, 'dm-ysd-encrypted/encrypted'
    autoload :TextEncrypted, 'dm-ysd-encrypted/encrypted'
  end
end

