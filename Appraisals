rails_versions = [
  '~> 4.0.0', 
  '~> 4.1.0', 
  '~> 4.2.0', 
  '~> 5.0.0', 
  '~> 5.1.0', 
  '~> 5.2.0', 
  '~> 6.0.0', 
  '~> 6.1.0',
]

rails_versions.each do |version|
  version_str = version.slice(/\d+\.\d+/).tr('.', '-')

  appraise "rails_#{version_str}" do
    gem 'rails', version
  end
end
