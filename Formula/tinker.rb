# Documentation: https://docs.brew.sh/Formula-Cookbook
#                https://rubydoc.brew.sh/Formula
# PLEASE REMOVE ALL GENERATED COMMENTS BEFORE SUBMITTING YOUR PULL REQUEST!
class Tinker < Formula
  desc 'Install the Tinker toolset.'
  homepage 'https://github.com/bodyshopbidsdotcom/tinker'
  # pass the --HEAD parameter to install a dev version from remote and branch
  head 'https://github.com/bodyshopbidsdotcom/tinker.git', :branch => 'release' # (the default is 'master')
                                         # or :tag => '1_0_release',
                                         # or :revision => '090930930295adslfknsdfsdaffnasd13'
  url 'https://github.com/bodyshopbidsdotcom/tinker/archive/v0.0.1.tar.gz', :using => GitHubPrivateRepositoryDownloadStrategy
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
