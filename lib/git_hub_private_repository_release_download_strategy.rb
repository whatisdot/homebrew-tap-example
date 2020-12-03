require_relative 'git_hub_private_repository_download_strategy'

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
