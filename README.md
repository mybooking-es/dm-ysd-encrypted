dm-encrypted
======
A [DataMapper](http://github.com/datamapper/data_mapper)
[type](http://github.com/datamapper/dm-more/tree/master/dm-types) that supports
encrypted columns.

It's a fork of qhoxie/dm-encrypted project, hosted on Github. 

It works on DM 1.2 and allows the encryption of long strings.

It uses AES to crypt the cipher the data. The AES 256 bits key and the AES initialization vector
are both encrypted using a RSA key.


Installation
------------
    gem install dm-ysd-encrypted 

Usage
-----
Configure the Crypto:
    
    rsa_key = OpenSSL::PKey::RSA.generate(2048) 

    Crypto.configure({:rsa_key => my_rsa_key,
      :aes_key => rsa_key.public_encrypt(Digest::SHA2.new(256).digest('password')),
      :aes_iv => rsa_key.public_encrypt(rand.to_s)}

In your models, you simply specify the column type as Encrypted (String) or TextEncrypted (Text):

    class Account
      include DataMapper::Resource

      property :id,         Serial
      property :username,   String
      property :password,   Encrypted
    end

Saving and loading those fields will transparently work with plaintext:

    >> Account.create :username => "me", :password => "secret"
    >> Account.first.password
    => "secret"

However it is ciphertext in the database:

    >> select password from accounts;
    => qxZjz37mt2PU...tcHPf5Un3RGAyxaT==

Comments/Suggestions/Requests
----------------------------
Email me: yurak.sisa.dream@gmail.com

Copyright
---------
Copyright (c) 2009 Quin Hoxie. See LICENSE for details.
