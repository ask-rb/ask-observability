# frozen_string_literal: true

require_relative 'test_helper'

class GeneratorTest < Minitest::Test
  def test_generator_exists_and_writes_initializer
    root = File.expand_path('../lib/generators', __dir__)

    assert_path_exists File.join(root, 'ask/observability/install_generator.rb'),
                       'install generator missing'
    assert_path_exists File.join(root, 'ask/observability/install/templates/initializer.rb.erb'),
                       'initializer template missing'
  end

  def test_initializer_template_is_valid_ruby_and_configured
    template = File.read(
      File.expand_path('../lib/generators/ask/observability/install/templates/initializer.rb.erb', __dir__)
    )

    assert_includes template, 'Ask::Observability.configure do |config|'
    # The template must be valid Ruby (it's an ERB-free template).
    RubyVM::InstructionSequence.compile(template)
  rescue SyntaxError
    flunk 'initializer template is not valid Ruby'
  end
end
