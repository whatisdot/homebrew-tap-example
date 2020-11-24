require 'download_strategy'

###
# Taken from code removed from the homebrew source. They now recommend people
# define these in their formula. See this link for details:
#   https://github.com/Homebrew/brew/pull/5112/
class GitHubPrivateRepositoryDownloadStrategy < CurlDownloadStrategy
  require "utils/formatter"
  require "utils/github"

  def initialize(url, name, version, **meta)
    super
    parse_url_pattern
    set_github_token
  end

  def parse_url_pattern
    unless match = url.match(%r{https://github.com/([^/]+)/([^/]+)(/\S*)*})
      raise CurlDownloadStrategyError, "Invalid url pattern for GitHub Repository."
    end

    _, @owner, @repo, @filepath = *match
  end

  def download_url
    "https://#{@github_token}@github.com/#{@owner}/#{@repo}#{@filepath}"
  end

  private

  def _fetch(url:, resolved_url:)
    curl_download download_url, to: temporary_path
  end

  def set_github_token
    require 'pry';binding.pry
    @github_token = ENV["GITHUB_OAUTH_CREDENTIALS"]
    unless @github_token
      raise CurlDownloadStrategyError, "Environmental variable GITHUB_OAUTH_CREDENTIALS is required."
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
      GITHUB_OAUTH_CREDENTIALS can not access the repository: #{@owner}/#{@repo}
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
    url_pattern = %r{https://github.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(\S+)}
    unless @url =~ url_pattern
      raise CurlDownloadStrategyError, "Invalid url pattern for GitHub Release."
    end

    _, @owner, @repo, @tag, @filename = *@url.match(url_pattern)
  end

  def download_url
    "https://#{@github_token}@api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}"
  end

  private

  def _fetch(url:, resolved_url:)
    # HTTP request header `Accept: application/octet-stream` is required.
    # Without this, the GitHub API will respond with metadata, not binary.
    curl_download download_url, "--header", "Accept: application/octet-stream", to: temporary_path
  end

  def asset_id
    @asset_id ||= resolve_asset_id
  end

  def resolve_asset_id
    release_metadata = fetch_release_metadata
    assets = release_metadata["assets"].select { |a| a["name"] == @filename }
    raise CurlDownloadStrategyError, "Asset file not found." if assets.empty?

    assets.first["id"]
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
  head 'https://github.com/bodyshopbidsdotcom/tinker.git', :branch => 'master' # (the default is 'master')
                                         # or :tag => '1_0_release',
                                         # or :revision => '090930930295adslfknsdfsdaffnasd13'
  url 'https://github.com/bodyshopbidsdotcom/tinker.git', :using => GitHubPrivateRepositoryDownloadStrategy
  # url 'https://github.com/bodyshopbidsdotcom/tinker/archive/v0.0.1.tar.gz', :using => GitHubPrivateRepositoryDownloadStrategy
  sha256 '0ae1feb1c90b326afe140db94a7833cd0d466b0a7a3767a87431eadb9d5900e7'
  license 'MIT'
  version '0.0.1'

  uses_from_macos 'ruby'

  depends_on 'cmake'
  depends_on 'pkg-config'

  def install
    # ENV.deparallelize  # if your formula fails when building in parallel
    ENV['GEM_HOME'] = libexec
    system 'bundle', 'install'
    system 'gem', 'build', "#{name}.gemspec"
    system 'gem', 'install', "#{name}-#{version}.gem"
    bin.install libexec/"bin/#{name}"
    bin.env_script_all_files(libexec/'bin', :GEM_HOME => ENV['GEM_HOME'])
  end

  test do
    # `test do` will create, run in and delete a temporary directory.
    #
    # This test will fail and we won't accept that! For Homebrew/homebrew-core
    # this will need to be a test that verifies the functionality of the
    # software. Run the test with `brew test tinker`. Options passed
    # to `brew install` such as `--HEAD` also need to be provided to `brew test`.
    #
    # The installed folder is not in the path, so use the entire path to any
    # executables being tested: `system '#{bin}/program', 'do', 'something'`.
    system 'false'
  end
end
