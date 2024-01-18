local treesitter_query_id_and_classes = [[
  (id_selector (id_name)@id_name)
  (class_selector (class_name)@class_name)
]]

local treesitter_html_tags = [[
  (style_element (raw_text)@raw_text)
  (element (start_tag)@start_tag)
  (element (self_closing_tag)@self_closing_tag)
]]

return {
    treesitter_query_id_and_classes = treesitter_query_id_and_classes,
    treesitter_html_tags = treesitter_html_tags,
}
