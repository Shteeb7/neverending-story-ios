#!/usr/bin/env ruby
#
# Fix Xcode project file - remove corrupted BugReport references and re-add correctly
#

require 'xcodeproj'

project_path = 'NeverendingStory.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🔧 Fixing Xcode project file..."

# Find the main target
target = project.targets.find { |t| t.name == 'NeverendingStory' }
unless target
  puts "❌ Could not find NeverendingStory target"
  exit 1
end

# STEP 1: Remove all BugReport-related file references (clean slate)
puts "\n🧹 Removing old BugReport file references..."

removed_count = 0
project.files.each do |file_ref|
  if file_ref.path&.include?('BugReport') || file_ref.path&.include?('SettingsView')
    puts "   Removing: #{file_ref.path}"

    # Remove from build phases
    target.source_build_phase.files.each do |build_file|
      if build_file.file_ref == file_ref
        target.source_build_phase.files.delete(build_file)
      end
    end

    # Remove file reference
    file_ref.remove_from_project
    removed_count += 1
  end
end

puts "✅ Removed #{removed_count} old file references"

# STEP 2: Find or create groups
puts "\n📁 Setting up groups..."

views_group = project.main_group['NeverendingStory']['Views']
unless views_group
  puts "❌ Could not find Views group"
  exit 1
end

# Create or find BugReport group
bug_report_group = views_group['BugReport'] || views_group.new_group('BugReport', 'NeverendingStory/Views/BugReport')
puts "✅ BugReport group ready"

# Create or find Settings group
settings_group = views_group['Settings'] || views_group.new_group('Settings', 'NeverendingStory/Views/Settings')
puts "✅ Settings group ready"

# STEP 3: Add files with correct paths
puts "\n📝 Adding files to project..."

def add_file(project, group, file_name, relative_path, target)
  # Check if already exists
  existing = group.files.find { |f| f.path == file_name }
  if existing
    puts "   ⚠️  #{file_name} already exists, skipping"
    return
  end

  # Add file reference
  file_ref = group.new_reference(relative_path)
  puts "   ✅ Added: #{file_name}"

  # Add to compile sources
  target.source_build_phase.add_file_reference(file_ref)
  puts "      → Added to compile sources"
end

# BugReport files
bug_report_files = [
  'BugReportOverlay.swift',
  'BugReportView.swift',
  'BugReportVoiceView.swift',
  'BugReportTextChatView.swift',
  'BugReportConfirmationView.swift'
]

bug_report_files.each do |filename|
  add_file(
    project,
    bug_report_group,
    filename,
    "NeverendingStory/Views/BugReport/#{filename}",
    target
  )
end

# Settings files
add_file(
  project,
  settings_group,
  'SettingsView.swift',
  'NeverendingStory/Views/Settings/SettingsView.swift',
  target
)

# STEP 4: Verify BugReportCaptureManager is in Services and build target
puts "\n🔍 Verifying BugReportCaptureManager..."

services_group = project.main_group['NeverendingStory']['Services']
capture_manager = services_group&.files&.find { |f| f.path == 'BugReportCaptureManager.swift' }

if capture_manager
  # Check if it's in build target
  in_build = target.source_build_phase.files.any? { |bf| bf.file_ref == capture_manager }

  if in_build
    puts "✅ BugReportCaptureManager.swift already in Services and build target"
  else
    target.source_build_phase.add_file_reference(capture_manager)
    puts "✅ Added BugReportCaptureManager.swift to build target"
  end
else
  puts "⚠️  BugReportCaptureManager.swift not found in Services (should already exist)"
end

# STEP 5: Save project
puts "\n💾 Saving project..."
project.save

puts "\n✅ Xcode project fixed successfully!"
puts "   Next: Run 'xcodebuild build' to verify"
