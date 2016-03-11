Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

branch, version, tag_name, tarball_url = ARGV

include Commands, Obs

version = version.sub('-', '~')
puts "Initating new build for emby-server, version: #{version}"
tarball = download_tarball(tarball_url, version, branch)
initiate_build(branch, version, tarball)
puts "Done!"
