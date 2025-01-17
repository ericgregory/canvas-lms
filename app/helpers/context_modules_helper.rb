#
# Copyright (C) 2011 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

module ContextModulesHelper
  def cache_if_module(context_module, editable, user, context, &block)
    if context_module
      visible_assignments = user ? user.assignment_and_quiz_visibilities(context) : []
      cache_key_items = ['context_module_render_14_', context_module.cache_key, editable, true, Time.zone, Digest::MD5.hexdigest(visible_assignments.to_s)]
      cache_key = cache_key_items.join('/')
      cache_key = add_menu_tools_to_cache_key(cache_key)
      cache(cache_key, nil, &block)
    else
      yield
    end
  end

  def add_menu_tools_to_cache_key(cache_key)
    tool_key = @menu_tools && @menu_tools.values.flatten.map(&:cache_key).join("/")
    cache_key += Digest::MD5.hexdigest(tool_key) if tool_key.present?
    # should leave it alone if there are no tools
    cache_key
  end

  def preload_can_unpublish(context, modules)
    items = modules.map(&:content_tags).flatten.map(&:content)
    asmnts = items.select{|item| item.is_a?(Assignment)}
    topics = items.select{|item| item.is_a?(DiscussionTopic)}
    quizzes = items.select{|item| item.is_a?(Quizzes::Quiz)}
    wiki_pages = items.select{|item| item.is_a?(WikiPage)}

    assmnt_ids_with_subs = Assignment.assignment_ids_with_submissions(context.assignments.pluck(:id))
    Assignment.preload_can_unpublish(asmnts, assmnt_ids_with_subs)
    DiscussionTopic.preload_can_unpublish(context, topics, assmnt_ids_with_subs)
    Quizzes::Quiz.preload_can_unpublish(quizzes, assmnt_ids_with_subs)
    WikiPage.preload_can_unpublish(context, wiki_pages)
  end

  def module_item_publishable_id(item)
    if item.nil?
      ''
    elsif (item.content_type == 'WikiPage')
      item.content.url
    else
      (item.content && item.content.respond_to?(:published?) ? item.content.id : item.id)
    end
  end

  def module_item_publishable?(item)
    true
  end

  def prerequisite_list(prerequisites)
    prerequisites.map {|p| p[:name]}.join(', ')
  end

  def module_item_unpublishable?(item)
    return true if item.nil? || !item.content || !item.content.respond_to?(:can_unpublish?)
    item.content.can_unpublish?
  end

  def module_item_translated_content_type(item)
    return '' unless item

    case item.content_type
    when 'Announcement'
      I18n.t('Announcement')
    when 'Assignment'
      I18n.t('Assignment')
    when 'Attachment'
      I18n.t('Attachment')
    when 'ContextExternalTool'
      I18n.t('External Tool')
    when 'ContextModuleSubHeader'
      I18n.t('Context Module Sub Header')
    when 'DiscussionTopic'
      I18n.t('Discussion Topic')
    when 'ExternalUrl'
      I18n.t('External Url')
    when 'Quiz'
      I18n.t('Quiz')
    when 'Quizzes::Quiz'
      I18n.t('Quiz')
    when 'WikiPage'
      I18n.t('Wiki Page')
    else
      I18n.t('Unknown Content Type')
    end
  end
end
