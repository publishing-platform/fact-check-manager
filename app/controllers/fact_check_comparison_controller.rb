class FactCheckComparisonController < ApplicationController
  before_action :authenticate_user!, unless: :token_bypass?, only: :compare

  def compare
    @request = Request.most_recent_for_source(source_app: params[:source_app], source_id: params[:source_id])
    raise ActiveRecord::RecordNotFound, "No request found" unless @request

    return unless token_bypass? || check_permissions(current_user, @request)

    @current_content = @request.current_content.deep_symbolize_keys
    @previous_content = @request.previous_content&.deep_symbolize_keys.presence || @current_content.deep_dup

    # TODO: - remove debugging code below
    # @current_content = { first_part: { heading: "Body", body: "<h1>This is an updated heading</h1><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi vel velit orci. Nullam in turpis dictum, scelerisque sem nec, mollis nisi. Vivamus aliquet pellentesque dapibus. Aliquam erat volutpat.</p><h2>Sub-heading here</h2><p>Phasellus porttitor et orcix vitae faucibus. Mauris at leo quis velit tempor faucibus. Nulla gravida auctor magna maximus vulputate. Etiam eget placerat mauris.</p>" }, third_part: { heading: "Bodyy", body: "<h1>This is an updated heading</h1><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi vel velit orci. Nullam in turpis dictum, scelerisque sem nec, mollis nisi. Vivamus aliquet pellentesque dapibus. Aliquam erat volutpat.</p><h2>Sub-heading here</h2><p>Phasellus porttitor et orcix vitae faucibus. Mauris at leo quis velit tempor faucibus. Nulla gravida auctor magna maximus vulputate. Etiam eget placerat mauris.</p>" } }
    # @previous_content = { first_part: { heading: "Body", body: "<h1>This is a heading</h1><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi vel velit orci. Nullam in turpis dictum, scelerisque sem nec, mollis nisi. Vivamus aliquet pellentesque dapibus. Aliquam erat volutpat.</p><h2>Sub-heading here</h2><p>Phasellus porttitor et orci vitae faucibus. Mauris at leo quis velit tempor faucibus. Nulla gravida auctor magna maximus vulputate. Etiam eget placerat mauris.</p>" }, second_part: { heading: "Bodyx", body: "<h1>This is an updated heading</h1><p>Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi vel velit orci. Nullam in turpis dictum, scelerisque sem nec, mollis nisi. Vivamus aliquet pellentesque dapibus. Aliquam erat volutpat.</p><h2>Sub-heading here</h2><p>Phasellus porttitor et orcix vitae faucibus. Mauris at leo quis velit tempor faucibus. Nulla gravida auctor magna maximus vulputate. Etiam eget placerat mauris.</p>" } }

    mark_current_content
    @differ = create_diff
  end

private

  def mark_current_content
    # Both have a single content block, we can diff it directly
    if @current_content.size == 1 && @previous_content.size == 1
      return
    end

    # Else, content block matching
    mark_removed_in_current
    mark_added_in_current
  end

  # If the item doesn't exist in current, give it a blank
  # for accurate display of diff
  # Not needed for items that don't exist in previous as
  # current is the source of truth.
  def mark_removed_in_current
    current_part_ids = @current_content.keys

    current_content_array = Array(@current_content) # Allows index specific insertion

    @previous_content.each_with_index do |(previous_part_id, previous_part), index|
      next if current_part_ids.include?(previous_part_id)

      previous_part_heading = previous_part[:heading]
      insert_at = [index, current_content_array.length].min
      item_copy = { heading: "#{previous_part_heading} (REMOVED)", body: "" }
      current_content_array.insert(insert_at, [previous_part_id, item_copy])

      current_part_ids << previous_part_id
    end

    @current_content = current_content_array.to_h
  end

  def mark_added_in_current
    @current_content.each do |part_id, current_part|
      current_part_heading = current_part[:heading]

      @current_content[part_id][:heading] = "#{current_part_heading} (ADDED)" if @previous_content[part_id].blank?
    end
  end

  def create_diff
    diff_hash = {}

    @current_content.each do |part_id, current_part|
      current_part_heading = current_part[:heading]
      current_part_content = current_part[:body]

      previous_part_content = @previous_content.dig(part_id, :body)

      heading = @current_content.size == 1 ? nil : current_part_heading

      diff_hash[heading] = PublishingPlatformNokodiff.diff(previous_part_content, current_part_content)
    end

    diff_hash
  end

  def token_bypass?
    return false if bypass_params[:token].blank?

    current_request = Request.most_recent_for_source(source_app: bypass_params[:source_app], source_id: bypass_params[:source_id])
    return unless current_request

    valid_compare_preview_jwt?(bypass_params[:token], current_request)
  end

  def bypass_params
    params.permit(:source_app, :source_id, :token)
  end
end
