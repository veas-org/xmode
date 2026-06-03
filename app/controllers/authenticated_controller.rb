class AuthenticatedController < ApplicationController
  CATALOG_PER_PAGE_OPTIONS = [ 10, 25, 50 ].freeze
  CatalogPagination = Struct.new(:page, :per_page, :total_count, :total_pages, :from, :to, :previous_page, :next_page, keyword_init: true)

  before_action :require_login!
  before_action :ensure_workspace!

  layout "app"

  private

  def ensure_workspace!
    return if current_workspace

    redirect_to new_workspace_path, alert: "Create a workspace to continue."
  end

  def load_catalog_navigation(active:)
    @catalog_navigation = build_catalog_navigation(catalog_navigation_entries(active))
  end

  def catalog_navigation_entries(active)
    case active
    when ActionDefinition
      action_entries(active)
    when SkillDefinition
      skill_entries(active)
    when PipelineDefinition
      pipeline_entries(active)
    else
      skill_entries(active) + action_entries(active) + pipeline_entries(active)
    end
  end

  def skill_entries(active)
    current_workspace.skill_definitions.order(:category, :name, :version).map do |skill|
      {
        path: catalog_segments(skill.category, skill.versioned_key),
        label: skill.name,
        subtitle: skill.versioned_key,
        href: skill_path(skill),
        active: catalog_active?(skill, active)
      }
    end
  end

  def action_entries(active)
    current_workspace.action_definitions.includes(:skill_definition).order(:category, :name, :version).map do |action|
      {
        path: catalog_segments(action.category, action.versioned_key),
        label: action.name,
        subtitle: action.versioned_key,
        href: action_path(action),
        active: catalog_active?(action, active)
      }
    end
  end

  def pipeline_entries(active)
    current_workspace.pipeline_definitions.order(:name, :version).map do |pipeline|
      {
        path: catalog_segments(pipeline_folder(pipeline), pipeline.versioned_key),
        label: pipeline.name,
        subtitle: pipeline.versioned_key,
        href: pipeline_path(pipeline),
        active: catalog_active?(pipeline, active)
      }
    end
  end

  def build_catalog_navigation(entries)
    nodes = []
    entries.each { |entry| insert_catalog_navigation_entry(nodes, entry) }
    finalize_catalog_navigation(nodes)
  end

  def insert_catalog_navigation_entry(nodes, entry)
    folder_nodes = nodes
    entry.fetch(:path)[0...-1].each do |segment|
      folder = folder_nodes.find { |node| node[:kind] == :folder && node[:key] == segment }
      unless folder
        folder = { kind: :folder, key: segment, label: segment.to_s.tr("_-", " ").titleize, active: false, children: [] }
        folder_nodes << folder
      end
      folder[:active] ||= entry[:active]
      folder_nodes = folder[:children]
    end

    folder_nodes << entry.slice(:label, :subtitle, :href, :active).merge(kind: :file, key: entry.fetch(:path).last)
  end

  def finalize_catalog_navigation(nodes)
    nodes.sort_by! { |node| [ node[:kind] == :folder ? 0 : 1, node[:label].to_s.downcase ] }
    nodes.each do |node|
      next unless node[:kind] == :folder

      node[:children] = finalize_catalog_navigation(node[:children])
      node[:count] = catalog_leaf_count(node[:children])
      node[:active] ||= node[:children].any? { |child| child[:active] }
    end
    nodes
  end

  def catalog_leaf_count(nodes)
    nodes.sum { |node| node[:kind] == :file ? 1 : catalog_leaf_count(node[:children]) }
  end

  def catalog_segments(*values)
    values.flat_map { |value| value.to_s.split("/") }.map(&:strip).reject(&:blank?)
  end

  def catalog_active?(record, active)
    active.present? && record.class == active.class && record.id == active.id
  end

  def pipeline_folder(pipeline)
    triggers = pipeline.triggers.to_a
    return "event-triggered" if triggers.any? { |trigger| trigger.to_s.include?("event") }
    return "scheduled" if triggers.any? { |trigger| trigger.to_s.include?("schedule") || trigger.to_s.include?("cron") }

    triggers.first.presence || "manual"
  end

  def catalog_query
    params[:q].to_s.strip
  end

  def catalog_like_query(value)
    "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
  end

  def paginate_catalog(collection)
    per_page = catalog_per_page
    page = params[:page].to_i
    page = 1 if page < 1

    total_count = collection.is_a?(Array) ? collection.size : collection.count
    total_pages = [ (total_count.to_f / per_page).ceil, 1 ].max
    page = total_pages if page > total_pages
    offset = (page - 1) * per_page

    records = if collection.is_a?(Array)
      collection.slice(offset, per_page) || []
    else
      collection.offset(offset).limit(per_page)
    end

    [
      records,
      CatalogPagination.new(
        page: page,
        per_page: per_page,
        total_count: total_count,
        total_pages: total_pages,
        from: total_count.zero? ? 0 : offset + 1,
        to: [ offset + per_page, total_count ].min,
        previous_page: page > 1 ? page - 1 : nil,
        next_page: page < total_pages ? page + 1 : nil
      )
    ]
  end

  def catalog_per_page
    requested = params[:per_page].to_i
    CATALOG_PER_PAGE_OPTIONS.include?(requested) ? requested : CATALOG_PER_PAGE_OPTIONS.first
  end

  def catalog_front_page?(*filter_keys)
    request.format.html? && params[:mode] != "list" && filter_keys.all? { |key| params[key].blank? }
  end

  def preferred_catalog_record(scope, preferred_keys:)
    records_by_key = scope.where(key: preferred_keys).index_by(&:key)
    preferred_keys.filter_map { |key| records_by_key[key] }.first || scope.first
  end

  def track_catalog_version(record, source:)
    return unless record.respond_to?(:catalog_version_source=)

    record.catalog_version_source = source
    record.catalog_version_user = current_user
  end
end
