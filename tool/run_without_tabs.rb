# frozen_string_literal: true
# This is a script to run a command in ARGV, expanding tabs in some files
# included by vm.c to normalize indentation of MJIT header.
#
# Note that preprocessor of GCC converts a hard tab to one spaces, where
# we expect it to be shown as 8 spaces. To obviate this script, we need
# to convert all tabs to spaces in these files.

require 'fileutils'

# These files have no hard tab indentations. Skip normalizing these files.
SKIPPED_FILES = %w[
  vm_callinfo.h
  vm_debug.h
  vm_exec.h
  vm_opts.h
]

srcdir = File.expand_path('..', __dir__)
targets = Dir.glob(File.join(srcdir, 'vm*.*')) - SKIPPED_FILES.map { |f| File.join(srcdir, f) }
sources = {}
mtimes = {}

targets.each do |target|
  unless File.writable?(target)
    puts "tool/run_without_tabs.rb: Skipping #{target.dump} as it's not writable."
    next
  end
  source = File.read(target)
  begin
    expanded = source.gsub(/^\t+/) { |tab| ' ' * 8 * tab.length }
  rescue ArgumentError # invalid byte sequence in UTF-8 (Travis, RubyCI)
    puts "tool/run_without_tabs.rb: Skipping #{target.dump} as the encoding is #{source.encoding}."
    next
  end

  sources[target] = source
  mtimes[target] = File.mtime(target)

  if sources[target] == expanded
    puts "#{target.dump} has no hard tab indentation. This should be ignored in tool/run_without_tabs.rb."
  end
  File.write(target, expanded)
  FileUtils.touch(target, mtime: mtimes[target])
end

result = system(*ARGV)

targets.each do |target|
  if sources.key?(target)
    File.write(target, sources[target])
    FileUtils.touch(target, mtime: mtimes.fetch(target))
  end
end

exit result
