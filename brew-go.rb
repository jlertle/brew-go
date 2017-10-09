#!/usr/bin/env ruby

def helpme
  puts <<~HEREDOC
    Manage Go packages via brew.

    Usage:
      brew go get <url to package> ...
      brew go list [keg]

    Examples:
      brew go get golang.org/x/perf/cmd/benchstat
      brew list brew-go-benchstat
  HEREDOC
  exit 1
end

def cmd_get(packages)
  threads = []
  packages.each do |url|
    threads << Thread.new do
      name = File.basename url
      cellarpath = "#{HOMEBREW_CELLAR}/brew-go-#{name}"
      gopath = "#{cellarpath}/#{url.gsub('/', '#')}"

      ENV["GOPATH"] = gopath
      ENV.delete "GOBIN"

      system "go get #{url}"
      unless $?.success?
        puts "[\x1b[31;1m✗\x1b[0m] #{url}"
        FileUtils.remove_dir "#{cellarpath}", true
        Thread.exit
      end

      puts "[\x1b[32;1m✓\x1b[0m] \x1b[1mbrew-go-#{name}\x1b[0m <- #{url}"

      FileUtils.remove_dir "#{gopath}/pkg", true
      FileUtils.remove_dir "#{gopath}/src", true

      system "brew unlink brew-go-#{name}", out: File::NULL
      system "brew link brew-go-#{name}", out: File::NULL
    end
  end
  threads.each { |thr| thr.join }
end

def cmd_list(name)
  if name.nil?
    puts Dir["#{HOMEBREW_CELLAR}/brew-go-*"].map { |dir| File.basename dir }
    return
  end

  path = "#{HOMEBREW_CELLAR}/#{name}"
  if Dir.exist? path
    puts Dir["#{path}/**/*"].select { |f| File.file? f }
  else
    puts "No such keg: #{path}"
    exit 1
  end
end

def cmd_update(names)
  urls = if names.empty?
           Dir["#{HOMEBREW_CELLAR}/brew-go-*/*"].map do |path|
             get_url_from_cellar_path path
           end
         else
           names.map do |name|
             get_url_from_cellar_path Dir["#{HOMEBREW_CELLAR}/#{name}/*"].first
           end
         end
  cmd_get urls
end

def get_url_from_cellar_path(path)
  File.basename(path).gsub '#', '/'
end

case ARGV.shift
when 'get', 'ge', 'g'
  helpme if ARGV.empty?
  cmd_get ARGV
when 'list', 'lis', 'li', 'l'
  cmd_list ARGV.first
when 'update', 'updat', 'upda', 'upd', 'up', 'u'
  cmd_update ARGV
else
  helpme
end
