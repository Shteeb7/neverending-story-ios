#!/usr/bin/env ruby
# Add bug reporting files to Xcode project

require 'xcodeproj'

PROJECT_PATH = File.expand_path('../NeverendingStory.xcodeproj', __FILE__)
FILE_PATH = File.expand_path('../NeverendingStory/Services/BugReportCaptureManager.swift', __FILE__)

puts "Opening Xcode project: #{PROJECT_PATH}"
project = Xcodeproj::Project.open(PROJECT_PATH)

# Find the main app target
target = project.targets.find { |t| t.name == 'NeverendingStory' }
raise "Could not find NeverendingStory target" unless target

puts "Found target: #{target.name}"

# Find the Services group
services_group = project.main_group['NeverendingStory']['Services']
raise "Could not find Services group" unless services_group

puts "Found Services group"

# Check if file already exists in project
existing_file = services_group.files.find { |f| f.path == 'BugReportCaptureManager.swift' }

if existing_file
  puts "File already exists in project, removing old reference..."

  # Remove from build phase
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == existing_file
      target.source_build_phase.remove_build_file(build_file)
    end
  end

  # Remove from group
  existing_file.remove_from_project
end

puts "Adding BugReportCaptureManager.swift to Services group..."

# Add file to group with correct relative path
file_ref = services_group.new_file('BugReportCaptureManager.swift')
file_ref.set_source_tree('<group>')

# Add to build phase (compile sources)
target.source_build_phase.add_file_reference(file_ref)

puts "✅ Added BugReportCaptureManager.swift to project and compile sources"

# Save the project
project.save
puts "✅ Project saved successfully"
