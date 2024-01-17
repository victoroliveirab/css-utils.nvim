local treesitter_query_id_and_classes = [[
  (id_selector (id_name)@id_name)
  (class_selector (class_name)@class_name)
]]

return {
    treesitter_query_id_and_classes = treesitter_query_id_and_classes,
}
