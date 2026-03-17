# frozen_string_literal: true

require_relative "lib/vb/version"

Gem::Specification.new do |spec|
  spec.name = "vb"
  spec.version = VB::VERSION
  spec.authors = ["vb"]
  spec.summary = "Workspace manager for AI coding agents"
  spec.files = Dir["lib/**/*.rb", "exe/*"]
  spec.bindir = "exe"
  spec.executables = ["vb"]
  spec.required_ruby_version = ">= 3.1"
  spec.add_dependency "thor", "~> 1.0"
end
