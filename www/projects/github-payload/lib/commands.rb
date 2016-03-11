require 'open-uri'
require 'fileutils'

module Commands
  def download_tarball(url, version, branch)
    clean()
    filename = "/tmp/emby-server-#{version}.tar"
    dirname = get_dirname(version, branch)
    File.open("#{filename}", "wb") do |saved_filename|
      open("#{url}", "rb") do |read_filename|
        saved_filename.write(read_filename.read)
      end
    end
    return gzip_tarball(filename, dirname)
  end

  def gzip_tarball(tarball, dirname)
    mkdir(dirname)
    extract_tarball(tarball, dirname)
    compress_dir(dirname)
    return "#{dirname}.tar.gz"
  end

  def mkdir(dirname)
    system "mkdir -p #{dirname}"
  end

  def clean()
    FileUtils.rm Dir.glob("/tmp/*.tar.gz")
  end

  def extract_tarball(tarball, dirname)
    system "tar xf #{tarball} --strip-components=1 -C #{dirname}"
    remove_file(tarball)
  end

  def compress_dir(dirname)
    subdirname = dirname.sub('/tmp/','')
    system "tar czf #{dirname}.tar.gz -C /tmp #{subdirname}"
    remove_dir(dirname)
  end

  def remove_file(filename)
    if File.exist?(filename)
      File.delete(filename)
    end
  end

  def remove_dir(dirname)
    if Dir.exists?(dirname)
      FileUtils.rm_rf(dirname)
    end
  end

  def get_dirname(version, branch)
    if branch == "master"
      return "/tmp/emby-server-#{version}"
    else
      return "/tmp/emby-server-#{branch}-#{version}"
    end
  end
end
