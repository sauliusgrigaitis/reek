require File.join( File.dirname( File.expand_path(__FILE__)), 'detector_stack')
require File.join( File.dirname( File.expand_path(__FILE__)), 'code_parser')

# SMELL: Duplication -- all these should be found automagically
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'attribute')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'boolean_parameter')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'class_variable')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'control_couple')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'data_clump')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'duplication')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'feature_envy')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'irresponsible_module')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'large_class')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'long_method')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'long_parameter_list')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'long_yield_list')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'nested_iterators')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'simulated_polymorphism')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'uncommunicative_method_name')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'uncommunicative_module_name')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'uncommunicative_parameter_name')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'uncommunicative_variable_name')
require File.join( File.dirname( File.expand_path(__FILE__)), 'smells', 'utility_function')
require 'yaml'

#
# Extensions to +Hash+ needed by Reek.
#
class Hash
  def push_keys(hash)
    keys.each {|key| hash[key].adopt!(self[key]) }
  end

  def adopt!(other)
    other.keys.each do |key|
      ov = other[key]
      if Array === ov and has_key?(key)
        self[key] += ov
      else
        self[key] = ov
      end
    end
    self
  end
  
  def adopt(other)
    self.deep_copy.adopt!(other)
  end
  
  def deep_copy
    YAML::load(YAML::dump(self))
  end
end

module Reek

  #
  # Configures all available smell detectors and applies them to a source.
  #
  class Sniffer

    def self.smell_classes
      # SMELL: Duplication -- these should be loaded by listing the files
      [
        Smells::Attribute,
        Smells::BooleanParameter,
        Smells::ClassVariable,
        Smells::ControlCouple,
        Smells::DataClump,
        Smells::Duplication,
        Smells::FeatureEnvy,
        Smells::IrresponsibleModule,
        Smells::LargeClass,
        Smells::LongMethod,
        Smells::LongParameterList,
        Smells::LongYieldList,
        Smells::NestedIterators,
        Smells::SimulatedPolymorphism,
        Smells::UncommunicativeMethodName,
        Smells::UncommunicativeModuleName,
        Smells::UncommunicativeParameterName,
        Smells::UncommunicativeVariableName,
        Smells::UtilityFunction,
      ]
    end

    def initialize(src)
      @already_checked_for_smells = false
      @typed_detectors = nil
      @detectors = Hash.new
      Sniffer.smell_classes.each do |klass|
        @detectors[klass] = DetectorStack.new(klass.new(src.desc))
      end
      @source = src
      src.configure(self)
    end

    def check_for_smells
      return if @already_checked_for_smells
      CodeParser.new(self).process(@source.syntax_tree)
      @already_checked_for_smells = true
    end

    def configure(klass, config)
      @detectors[klass].push(config)
    end

    def report_on(report)
      check_for_smells
      @detectors.each_value { |stack| stack.report_on(report) }
    end

    def examine(scope, type)
      listeners = smell_listeners[type]
      listeners.each {|smell| smell.examine(scope) } if listeners
    end

    def smelly?
      check_for_smells
      @detectors.each_value { |stack| return true if stack.smelly? }
      false
    end

    def num_smells
      check_for_smells
      total = 0
      @detectors.each_value { |stack| total += stack.num_smells }
      total
    end

    def desc
      # SMELL: Special Case
      # Only used in the Report tests, because they don't always create a Source.
      @source ? @source.desc : "unknown"
    end

    #
    # Checks for instances of +smell_class+, and returns +true+
    # only if one of them has a report string matching all of the +patterns+.
    #
    def has_smell?(smell_class, patterns=[])
      check_for_smells
      stack = @detectors[Reek::Smells.const_get(smell_class)]      # SMELL: Duplication of code in ConfigFile
      stack.has_smell?(patterns)
    end

    def sniff
      self
    end

    def sniffers
      [self]
    end

private

    def smell_listeners()
      unless @typed_detectors
        @typed_detectors = Hash.new {|hash,key| hash[key] = [] }
        @detectors.each_value { |stack| stack.listen_to(@typed_detectors) }
      end
      @typed_detectors
    end
  end

  #
  # A composite, making a set of +Sniffer+s behave like a single +Sniffer+.
  #
  class SnifferSet

    attr_reader :desc, :sniffers

    def initialize(sniffers, desc)
      @sniffers = sniffers
      @desc = desc
    end

    def smelly?
      @sniffers.any? {|sniffer| sniffer.smelly? }
    end

    #
    # Checks for instances of +smell_class+, and returns +true+
    # only if one of them has a report string matching all of the +patterns+.
    #
    def has_smell?(smell_class, patterns=[])
      @sniffers.any? {|sniffer| sniffer.has_smell?(smell_class, patterns)}
    end

    def num_smells
      @sniffers.inject(0) {|total, sniffer| total += sniffer.num_smells}
    end

    def sniff
      self
    end
  end
end
