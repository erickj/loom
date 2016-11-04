$LOAD_PATH.push File.expand_path '../lib/', __FILE__
require 'loom/version'

Gem::Specification.new do |s|
  s.name = 'loom'
  s.description = 'Repeatable management of remote hosts over SSH'
  s.summary = s.description
  s.version = Loom::VERSION
  s.license = 'MIT'
  s.authors = ['Erick Johnson']
  s.email = 'ejohnson82@gmail.com'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- spec/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.require_paths = %w[lib]

  s.add_dependency 'sshkit', '~> 1.11'
  s.add_dependency 'commander', '~> 4.4'

  # Need net-ssh beta and its explicit requirements until for ed25519
  # elliptic curve key support
  # https://github.com/net-ssh/net-ssh/issues/214

  # grrr.. 4.x.beta won't work in `gem install` until the official
  # release due to net-scp gem dependencies.
  # I can manually `gem install net-ssh --version 4.0.0.beta3` for now.
  # s.add_dependency 'net-ssh', '>= 4.0.0.beta3'
  s.add_dependency 'net-ssh', '>= 3'
  s.add_dependency 'rbnacl-libsodium', '1.0.10'
  s.add_dependency 'bcrypt_pbkdf', '1.0.0.alpha1'

  s.add_development_dependency 'bundler', '~> 1.13'
  s.add_development_dependency 'rake', '~> 11.3'
  s.add_development_dependency 'rspec', '~> 3.5'
end
