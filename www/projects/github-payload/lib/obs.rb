require 'fileutils'

module Obs
  def initiate_build(branch, version, tarball)
    dirname = get_repodir(branch)
    update_repo(dirname)
    update_source(dirname, tarball)
    set_version(version, dirname)
    start_build(dirname)
  end

  def update_repo(dirname)
    system "osc up #{dirname}"
    system "osc clean #{dirname}"
  end

  def update_source(dirname, tarball)
    remove_source(dirname)
    FileUtils.mv "#{tarball}", "#{dirname}"
  end

  def remove_source(dirname)
    Dir.glob("#{dirname}/emby-serve*.tar.gz") do |tarball|
      FileUtils.rm(tarball)
    end
  end

  def set_version(version, dirname)
    service_file = "#{dirname}/_service"
    if File.exist?("#{service_file}")
      FileUtils.rm("#{service_file}")
    end
    File.open("#{service_file}", "wb") do |new_service_file|
      new_service_file.puts('<services>')
      new_service_file.puts('<service name="set_version">')
      new_service_file.write('<param name="version">')
      new_service_file.write("#{version}")
      new_service_file.puts('</param>')
      new_service_file.puts('</service>')
      new_service_file.puts('</services>')
    end
  end

  def get_repodir(branch)
    if branch != "master"
      return "/var/repos/emby-server-#{branch}"
    else
      return "/var/repos/emby-server"
    end
  end

  def get_source_tarball(dirname)
    return Dir.glob("#{dirname}/emby-server*.tar.gz")
  end

  def start_build(dirname)
    system "osc addremove #{dirname}"
    system "osc ci -m \"autobuild\" #{dirname}"
  end
end
