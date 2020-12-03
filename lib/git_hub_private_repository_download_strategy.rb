require 'download_strategy'

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
