# typed: true
# frozen_string_literal: true

require "cask/audit"

module Cask
  # Helper class for auditing all available languages of a cask.
  #
  # @api private
  class Auditor
    def self.audit(cask, **options)
      new(cask, **options).audit
    end

    attr_reader :cask, :language

    def initialize(
      cask,
      audit_download: nil,
      audit_online: nil,
      audit_strict: nil,
      audit_signing: nil,
      audit_token_conflicts: nil,
      audit_new_cask: nil,
      quarantine: nil,
      any_named_args: nil,
      language: nil,
      display_passes: nil,
      display_failures_only: nil,
      only: [],
      except: []
    )
      @cask = cask
      @audit_download = audit_download
      @audit_online = audit_online
      @audit_new_cask = audit_new_cask
      @audit_strict = audit_strict
      @audit_signing = audit_signing
      @quarantine = quarantine
      @audit_token_conflicts = audit_token_conflicts
      @any_named_args = any_named_args
      @language = language
      @display_passes = display_passes
      @display_failures_only = display_failures_only
      @only = only
      @except = except
    end

    LANGUAGE_BLOCK_LIMIT = 10

    def audit
      warnings = Set.new
      errors = Set.new

      if !language && language_blocks
        sample_languages = if language_blocks.length > LANGUAGE_BLOCK_LIMIT && !@audit_new_cask
          sample_keys = language_blocks.keys.sample(LANGUAGE_BLOCK_LIMIT)
          ohai "Auditing a sample of available languages: #{sample_keys.map { |lang| lang[0].to_s }.to_sentence}"
          language_blocks.select { |k| sample_keys.include?(k) }
        else
          language_blocks
        end

        sample_languages.each_key do |l|
          audit = audit_languages(l)
          summary = audit.summary(include_passed: output_passed?, include_warnings: output_warnings?)
          if summary.present? && output_summary?(audit)
            ohai "Auditing language: #{l.map { |lang| "'#{lang}'" }.to_sentence}" if output_summary?
            puts summary
          end
          warnings += audit.warnings
          errors += audit.errors
        end
      else
        audit = audit_cask_instance(cask)
        summary = audit.summary(include_passed: output_passed?, include_warnings: output_warnings?)
        puts summary if summary.present? && output_summary?(audit)
        warnings += audit.warnings
        errors += audit.errors
      end

      { warnings: warnings, errors: errors }
    end

    private

    def output_summary?(audit = nil)
      return true if @any_named_args.present?
      return true if @audit_strict.present?
      return false if audit.blank?

      audit.errors?
    end

    def output_passed?
      return false if @display_failures_only.present?
      return true if @display_passes.present?

      false
    end

    def output_warnings?
      return false if @display_failures_only.present?

      true
    end

    def audit_languages(languages)
      original_config = cask.config
      localized_config = original_config.merge(Config.new(explicit: { languages: languages }))
      cask.config = localized_config

      audit_cask_instance(cask)
    ensure
      cask.config = original_config
    end

    def audit_cask_instance(cask)
      audit = Audit.new(
        cask,
        online:          @audit_online,
        strict:          @audit_strict,
        signing:         @audit_signing,
        new_cask:        @audit_new_cask,
        token_conflicts: @audit_token_conflicts,
        download:        @audit_download,
        quarantine:      @quarantine,
        only:            @only,
        except:          @except,
      )
      audit.run!
    end

    def language_blocks
      cask.instance_variable_get(:@dsl).instance_variable_get(:@language_blocks)
    end
  end
end
