#!/usr/bin/env ruby
require 'xcodeproj'

project_path = 'NeverendingStory.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'NeverendingStoryUITests' }
raise "UITests target not found" unless target

ui_tests_group = project.main_group.find_subpath('NeverendingStoryUITests', true)
file_ref = ui_tests_group.new_reference('ScrollRestorationUITests.swift')
target.source_build_phase.add_file_reference(file_ref)

project.save
puts "✅ Added ScrollRestorationUITests.swift to Xcode project"
