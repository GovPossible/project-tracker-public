# frozen_string_literal: true

class TailwindBuilder < ActionView::Helpers::FormBuilder
  delegate :tag, :safe_join, to: :@template

  def default_override_classes
    "m-0 text-[16px]"
  end

  def default_classes
    "#{default_override_classes} p-3 w-full rounded-xl border-2 border-gray-300 focus-visible:border-purple-300 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-purple-600 shadow-inner shadow-gray-100 disabled:bg-gray-100 placeholder-gray-300"
  end

  def submit(value = nil, options = {})
    super(value, options.merge(class: "#{options[:class]} #{default_override_classes} px-3 py-2 inline-flex rounded-md bg-purple-600 hover:bg-purple-700 text-white cursor-pointer disabled:opacity-75 disabled:cursor-not-allowed"))
  end

  def label(method, text = nil, options = {})
    super(method, text, options.merge(class: "#{options[:class]} block text-gray-500 mb-2"))
  end

  def file_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_override_classes} w-full p-2 bg-gray-200 rounded-md disabled:bg-gray-100"))
  end

  def text_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def number_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def email_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def password_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def phone_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def date_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def datetime_field(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def text_area(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def rich_text_area(method, options = {})
    super(method, options.merge(class: "#{options[:class]} #{default_classes}"))
  end

  def error(method, message: nil, messages: nil)
    return unless @object&.errors&.include?(method)

    content = if messages.is_a?(Hash)
      msgs = @object.errors.where(method).map do |err|
        override = messages[err.type]
        override.presence || err.full_message
      end
      safe_join(msgs, tag.br)
    elsif message
      message
    else
      safe_join(@object.errors.full_messages_for(method), tag.br)
    end

    tag.div(content, class: "text-sm text-rose-600")
  end

  def check_box(method, options = {}, checked_value = "1", unchecked_value = "0")
    super(method, options.merge(class: "#{options[:class]} inline-block border-gray-300 rounded-md disabled:bg-gray-100"), checked_value, unchecked_value)
  end

  def select(method, choices = nil, options = {}, html_options = {}, &block)
    html_options[:data] ||= {}
    html_options[:data].merge!(options.delete(:data) || {})
    html_options[:class] = "#{html_options[:class]} #{options.delete(:class)} #{default_classes} w-full appearance-none rounded-md bg-white py-1.5 pl-3 pr-8 text-base text-gray-900"
    super
  end

  def collection_select(method, choices = nil, value_method = nil, text_method = nil, options = {}, html_options = {}, &block)
    html_options[:data] ||= {}
    html_options[:data].merge!(options.delete(:data) || {})
    html_options[:class] = "#{html_options[:class]} #{options.delete(:class)} #{default_classes} w-full appearance-none rounded-md bg-white py-1.5 pl-3 pr-8 text-base text-gray-900"
    super
  end

  def time_zone_select(method, priority_zones = nil, options = {}, html_options = {}, &block)
    html_options[:data] ||= {}
    html_options[:data].merge!(options.delete(:data) || {})
    html_options[:class] = "#{html_options[:class]} #{options.delete(:class)} #{default_classes}"
    super
  end
end
