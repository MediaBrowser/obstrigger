require 'sinatra'
require 'json'
require 'openssl'

post '/payload' do
  request.body.rewind
  payload_body = request.body.read
  verify_signature(payload_body)
  data = JSON.parse(payload_body)
  version_number = data['name']
  tag_name = data['tag_name']
  tarball_url = data['tarball_url']
  branch = data['target_commitish']
  puts "Updating OBS with #{branch} release #{tag_name}"
  Process.detach(fork{exec "ruby script.rb #{branch} #{version_number} #{tag_name} #{tarball_url}  &"})
end

def verify_signature(payload_body)
  if request.env['HTTP_X_HUB_SIGNATURE'] == nil
    puts "No token, provided"
    return halt 500, "No token provided!"
  else
    signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload_body)
    return halt 500, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
  end
end
