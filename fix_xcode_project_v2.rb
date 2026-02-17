#!/usr/bin/env ruby
#
# Fix Xcode project file - CORRECTED VERSION
# Path should be JUST the filename, not full path
#

require 'xcodeproj'

project_path = 'NeverendingStory.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing Xcode project file (v2)..."

# Find the main target
target = project.targets.find { |t| t.name == 'NeverendingStory' }
unless target
  puts "❌ Could not find NeverendingStory target"
  exit 1
end

# STEP 1: Remove ALL BugReport and SettingsView file references
puts "\n🧹 Removing all old file references..."

# First, collect file refs to remove (can't modify during iteration)
files_to_remove = []
project.files.each do |file_ref|
  if file_ref.path&.include?('BugReport') || file_ref.path&.include?('SettingsView')
    files_to_remove << file_ref
  end
end

files_to_remove.each do |file_ref|
  puts "   Removing: #{file_ref.hierarchy_path}"

  # Remove from build phases
  target.source_build_phase.files.each do |build_file|
    if build_file.file_ref == file_ref
      target.source_build_phase.files.delete(build_file)
    end
  end

  # Remove file reference
  file_ref.remove_from_project
end

puts "✅ Removed #{files_to_remove.count} file references"

# STEP 2: Find or create groups
puts "\n📁 Setting up groups..."

views_group = project.main_group['NeverendingStory']['Views']
services_group = project.main_group['NeverendingStory']['Services']

bug_report_group = views_group['BugReport'] || views_group.new_group('BugReport')
settings_group = views_group['Settings'] || views_group.new_group('Settings')
reader_group = views_group['Reader']

# STEP 3: Add files with JUST filename as path
puts "\n📝 Adding files..."

def add_file(group, filename, target)
  # Add with JUST the filename - group handles the rest
  file_ref = group.new_reference(filename)
  target.source_build_phase.add_file_reference(file_ref)
  puts "   ✅ #{filename}"
end

bug_report_files = [
  'BugReportOverlay.swift',
  'BugReportView.swift',
  'BugReportVoiceView.swift',
  'BugReportTextChatView.swift',
  'BugReportConfirmationView.swift'
]

puts "Adding BugReport files:"
bug_report_files.each { |f| add_file(bug_report_group, f, target) }

puts "Adding Settings files:"
add_file(settings_group, 'SettingsView.swift', target)

puts "Adding Services files:"
add_file(services_group, 'BugReportCaptureManager.swift', target)

puts "Adding Reader files:"
add_file(reader_group, 'ReaderSettingsView.swift', target)

# STEP 4: Save
puts "\n💾 Saving project..."
project.save

puts "✅ Done!"
