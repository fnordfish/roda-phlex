# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "standard/rake"

Rake::Task["spec"].enhance do
  sh "bundle", "exec", "rspec", "-t", "isolate", "spec/roda/delegation_error_spec.rb"
  sh "bundle", "exec", "rspec", "-t", "isolate", "spec/roda/delegation_spec.rb"
end

task default: %i[spec standard]
