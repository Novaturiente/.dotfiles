# Colored prompt segment (fg-only, no separator glyph).
# Usage: _pl_seg <content> <fg-hex>
function _pl_seg --argument-names content fg
    set_color $fg
    echo -n $content
    set_color normal
end
