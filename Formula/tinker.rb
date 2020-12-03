require_relative '../lib/git_hub_private_repository_release_download_strategy'

class Tinker < Formula
  desc 'Install the Tinker toolset.'
  homepage 'https://github.com/bodyshopbidsdotcom/tinker'
  # pass the --HEAD parameter to install a dev version from remote and branch
  head 'https://github.com/bodyshopbidsdotcom/tinker.git', branch: 'release' # (the default is 'master')
                                         # or :tag => '1_0_release',
                                         # or :revision => '090930930295adslfknsdfsdaffnasd13'

  # url 'https://github.com/bodyshopbidsdotcom/tinker', :using => GitHubPrivateRepositoryDownloadStrategy
  url 'https://github.com/bodyshopbidsdotcom/tinker/archive/v0.0.1.tar.gz', using: GitHubPrivateRepositoryReleaseDownloadStrategy

  sha256 '02631f9bb4aebd7b6cf5e63316be45d2908ba5a1a5a218d33a31840c283f38d3'
  license 'MIT'
  version '0.0.1'

  depends_on 'cmake' => '3.19.1'
  depends_on 'pkg-config' => '0.29.2_3'
  depends_on 'rbenv' => '1.1.2'

  def init_paths_and_versions(ruby_version)
    ruby_major_version = ruby_version.split('.').select{|s| Float(s) != nil rescue false}.first(2).join('.')
    ruby_major_version = "#{ruby_major_version}.0"
    rbenv_home = prefix/'.rbenv'
    ruby_home = rbenv_home/"versions/#{ruby_version}"
    gem_home = ruby_home/"lib/ruby/gems/#{ruby_major_version}"

    # Set environment to persist rbenv ruby version for tinker.
    ENV['GEM_HOME'] = gem_home
    ENV['GEM_PATH'] = "#{gem_home}:#{ENV['GEM_PATH']}"
    ENV['HOME'] = prefix.to_s
    ENV['PATH'] = "#{rbenv_home}/shims:#{ENV['PATH']}"
    ENV['RBENV_SHELL'] = 'ruby'
    ENV['RBENV_VERSION'] = ruby_version
  end

  def setup_debug_tools
    Homebrew.install_gem_setup_path! 'pry'
    Homebrew.install_gem_setup_path! 'pry-byebug', executable: 'pry'
    Homebrew.install_gem_setup_path! 'dotenv'
    require 'dotenv/load'
    require 'pry-byebug'
  end

  def install
    if Context.current.debug?
      self.setup_debug_tools
      @tap = CoreTap.instance unless self.tap?
    end

    # Setting our home directories and paths for ruby and gem installation.
    ruby_version = open('.ruby-version').read.strip
    self.init_paths_and_versions(ruby_version)
    system 'rbenv', 'rehash'

    # Install the required ruby version.
    system 'rbenv', 'install', ruby_version
    system 'rbenv', 'global', ruby_version
    system 'rbenv', 'rehash'
    system 'gem', 'build', "#{name}.gemspec"
    system 'gem', 'install', "#{name}-#{version}.gem"

    # Create env-wrapped references to original bins; save them in libexec.
    (prefix/".rbenv/versions/#{ruby_version}/bin").glob("*") do |original_file|
      target_file = libexec.join(original_file.basename)
      target_file.write_env_script(
        original_file,
        GEM_HOME: ENV['GEM_HOME'],
        GEM_PATH: ENV['GEM_PATH'],
        PATH: "#{prefix}/.rbenv/shims:$PATH",
        RBENV_VERSION: ruby_version
      )
      `chmod +x #{target_file}`
      bin.install(target_file)
    end
  end

  test do
    self.setup_debug_tools

    ruby_version = open(prefix/'.rbenv/version').read.strip
    self.init_paths_and_versions(ruby_version)

    assert_match "#{version}", '0.0.1'
    assert_true shell_output('ruby --version').include?(ruby_version)
  end
end
