#!/usr/bin/env ruby

# Add Peggy bug report files to Xcode project
# Run with: ruby add_bug_report_files.rb

require 'xcodeproj'

project_path = 'NeverendingStory.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Find the main target
target = project.targets.find { |t| t.name == 'NeverendingStory' }
unless target
  puts "❌ Could not find NeverendingStory target"
  exit 1
end

# Find or create Views/BugReport group
views_group = project.main_group['NeverendingStory']['Views']
unless views_group
  puts "❌ Could not find Views group"
  exit 1
end

bug_report_group = views_group['BugReport'] || views_group.new_group('BugReport')

# Find or create Views/Settings group
settings_group = views_group['Settings'] || views_group.new_group('Settings')

# Files to add (just the filename - group path is already set)
bug_report_files = [
  'BugReportOverlay.swift',
  'BugReportView.swift',
  'BugReportVoiceView.swift',
  'BugReportTextChatView.swift',
  'BugReportConfirmationView.swift'
]

settings_files = [
  'SettingsView.swift'
]

# Function to add file to group and target
def add_file_to_project(project, group, file_name, target, group_name)
  # Check if file already exists in group
  existing_file = group.files.find { |f| f.path == file_name }

  if existing_file
    puts "⚠️  File already in project: #{file_name}"
    # Remove from build phase first
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == existing_file
        target.source_build_phase.files.delete(build_file)
        puts "   Removed old build file reference"
      end
    end
    # Remove file reference
    existing_file.remove_from_project
    puts "   Removed old file reference"
  end

  # Construct the full path based on group
  full_path = "NeverendingStory/Views/#{group_name}/#{file_name}"

  # Add file reference
  file_ref = group.new_file(full_path)
  puts "✅ Added file reference: #{file_name}"
  puts "   Full path: #{full_path}"

  # Add to build phase (compile sources)
  target.source_build_phase.add_file_reference(file_ref)
  puts "   Added to compile sources"

  file_ref
end

# Add bug report files
puts "\n📁 Adding BugReport files..."
bug_report_files.each do |file_name|
  add_file_to_project(project, bug_report_group, file_name, target, 'BugReport')
end

# Add settings files
puts "\n📁 Adding Settings files..."
settings_files.each do |file_name|
  add_file_to_project(project, settings_group, file_name, target, 'Settings')
end

# Save project
puts "\n💾 Saving project..."
project.save

puts "✅ Done! All files added to Xcode project."
