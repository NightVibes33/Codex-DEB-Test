#!/usr/bin/env ruby
# frozen_string_literal: true

require 'xcodeproj'

project_path = ARGV.fetch(0)
project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |candidate| candidate.name == 'iOSSim' }
abort('iOSSim target not found') unless target

ios_group = project.main_group.find_subpath('iOSSim', false)
abort('iOSSim group not found') unless ios_group
runtime_group = ios_group.find_subpath('Runtime', false)
abort('iOSSim/Runtime group not found') unless runtime_group
kernel_group = runtime_group.find_subpath('VibeKernel', true)
kernel_group.set_source_tree('<group>')

sources = %w[VibeKernel.c VPhoneRuntime.swift]
headers = %w[VibeKernel.h]

sources.each do |name|
  ref = kernel_group.files.find { |file| file.path == name } || kernel_group.new_file(name)
  unless target.source_build_phase.files_references.include?(ref)
    target.source_build_phase.add_file_reference(ref)
  end
end

headers.each do |name|
  kernel_group.files.find { |file| file.path == name } || kernel_group.new_file(name)
end

target.build_configurations.each do |config|
  flags = config.build_settings['OTHER_LDFLAGS']
  flags = ['$(inherited)'] if flags.nil?
  flags = [flags] if flags.is_a?(String)
  marker_flag = '-Wl,-u,_VPhoneRuntimeBuildMarker'
  flags << marker_flag unless flags.include?(marker_flag)
  config.build_settings['OTHER_LDFLAGS'] = flags
end

project.save
puts "Injected VibeKernel sources into #{target.name}"
