Gem::Specification.new do |s|
  s.name = "dm-ysd-encrypted"
  s.version = "0.2.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Yurak Sisa"]
  s.date = "2013-02-27"
  s.description = "Transparently add encryption to DataMapper models."
  s.email = "yurak.sisa.dream@gmail.com"
  s.homepage = "http://github.com/yuraksisa/dm-encrypted"
  s.require_paths = ["lib"]
  s.summary = "Encrypted column type for DataMapper."
  s.files   = Dir['lib/**/*.rb','spec/**/*.rb']

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"
  s.add_development_dependency "data_mapper"
  s.add_development_dependency "rdoc"

end

