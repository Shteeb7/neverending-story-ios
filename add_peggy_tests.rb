#!/usr/bin/env ruby
#
# Add PeggyBugReportUITests.swift to NeverendingStoryUITests target
#

require 'xcodeproj'

project_path = 'NeverendingStory.xcodeproj'
project = Xcodeproj::Project.open(project_path)

puts "🧪 Adding Peggy UI tests to project..."

# Find the UITests target
target = project.targets.find { |t| t.name == 'NeverendingStoryUITests' }
unless target
  puts "❌ Could not find NeverendingStoryUITests target"
  exit 1
end

# Find or create the UITests group
ui_tests_group = project.main_group['NeverendingStoryUITests']
unless ui_tests_group
  puts "❌ Could not find NeverendingStoryUITests group"
  exit 1
end

# Add the test file
file_ref = ui_tests_group.new_reference('PeggyBugReportUITests.swift')
target.source_build_phase.add_file_reference(file_ref)
puts "   ✅ PeggyBugReportUITests.swift"

# Save
puts "\n💾 Saving project..."
project.save

puts "✅ Done!"
