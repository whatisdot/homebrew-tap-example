require 'download_strategy'

# Credit to debugging tip:
#   https://stevenharman.net/debugging-homebrew-with-pry-byebug#a-second-successful-attempt
def setup_debug_tools
  Homebrew.install_gem_setup_path! 'pry'
  Homebrew.install_gem_setup_path! 'pry-byebug', executable: 'pry'
  Homebrew.install_gem_setup_path! 'dotenv'
  require 'dotenv/load'
  require 'pry-byebug'
end

# Documentation on creating Formulas:
#   https://docs.brew.sh/Formula-Cookbook
#
# Test locally like this:
#   brew install --debug --verbose --build-from-source Formula/tinker.rb

###
# Taken from code removed from the homebrew source. They now recommend people
# define these in their formula. See this link for details:
#   https://github.com/Homebrew/brew/pull/5112/
class GitHubPrivateRepositoryDownloadStrategy < CurlDownloadStrategy
  require 'utils/formatter'
  require 'utils/github'

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    unless match = url.match(%r{https://github.com/([^/]+)/([^/]+)(/\S*)*})
      raise CurlDownloadStrategyError, 'Invalid url pattern for GitHub Repository.'
    end

    _, @owner, @repo, @filepath = *match
  end

  def download_url
    "https://api.github.com/#{@owner}/#{@repo}#{@filepath}"
  end

  private

  def _fetch(url:, resolved_url:)
    curl_download(
      download_url,
      '--header', "Authorization: token #{@github_token}",
      to: temporary_path
    )
  end

  def set_github_token
    @github_token = ENV['HOMEBREW_GITHUB_API_TOKEN']
    unless @github_token
      raise CurlDownloadStrategyError, 'Environmental variable HOMEBREW_GITHUB_API_TOKEN is required.'
    end

    validate_github_repository_access!
  end

  def validate_github_repository_access!
    # Test access to the repository
    GitHub.repository(@owner, @repo)
  rescue GitHub::HTTPNotFoundError
    # We only handle HTTPNotFoundError here,
    # becase AuthenticationFailedError is handled within util/github.
    message = <<~EOS
      HOMEBREW_GITHUB_API_TOKEN can not access the repository: #{@owner}/#{@repo}
      This token may not have permission to access the repository or the url of formula may be incorrect.
    EOS
    raise CurlDownloadStrategyError, message
  end
end

###
# Taken from code removed from the homebrew source. They now recommend people
# define these in their formula. See this link for details:
#   https://github.com/Homebrew/brew/pull/5112/
class GitHubPrivateRepositoryReleaseDownloadStrategy < GitHubPrivateRepositoryDownloadStrategy
  def initialize(url, name, version, **meta)
    super
  end

  def parse_url_pattern
    url_pattern = %r{https://github.com/([^/]+)/([^/]+)/archive/([^/]+)(\.tar\.gz|\.zip)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError, 'Invalid url pattern for GitHub Release.'
    end

    _, @owner, @repo, @tag, @file_extension = *@url.match(url_pattern)
    @filename = "#{@tag}#{@file_extension}"
  end

  def download_url
    "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
  end

  private

  def _fetch(url:, resolved_url:)
    curl_download(
      "#{fetch_release_metadata['tarball_url']}",
      '--header', 'Accept: application/vnd.github.v3+json',
      '--header', "Authorization: token #{@github_token}",
      to: temporary_path
    )
  end

  def asset_id
    @asset_id ||= resolve_asset_id
  end

  def resolve_asset_id
    release_metadata = fetch_release_metadata
    assets = release_metadata['assets'].select { |a| a['name'] == @filename }
    raise CurlDownloadStrategyError, 'Asset file not found.' if assets.empty?

    assets.first['id']
  end

  def fetch_release_metadata
    release_url = "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}"
    GitHub.open_api(release_url)
  end
end

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
