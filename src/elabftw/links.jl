# Cross-entity links

# =============================================================================
# Experiment ↔ Item links
# =============================================================================

"""
    link_experiment_to_item(experiment_id::Int, item_id::Int)

Create a link from an experiment to an item. The link appears on the experiment.

# Example
```julia
link_experiment_to_item(42, 7)  # Link experiment 42 → item 7
```
"""
function link_experiment_to_item(experiment_id::Int, item_id::Int)
    _link_entity("experiments", experiment_id, "items", item_id)
    return nothing
end

"""
    unlink_experiment_from_item(experiment_id::Int, item_id::Int)

Remove a link from an experiment to an item.
"""
function unlink_experiment_from_item(experiment_id::Int, item_id::Int)
    _unlink_entity("experiments", experiment_id, "items", item_id)
    return nothing
end

"""
    list_experiment_item_links(experiment_id::Int) -> Vector{Dict}

List all item links on an experiment.
"""
list_experiment_item_links(experiment_id::Int) = _list_entity_links("experiments", experiment_id, "items")

# =============================================================================
# Item ↔ Experiment links
# =============================================================================

"""
    link_item_to_experiment(item_id::Int, experiment_id::Int)

Create a link from an item to an experiment. The link appears on the item.

# Example
```julia
link_item_to_experiment(7, 42)  # Link item 7 → experiment 42
```
"""
function link_item_to_experiment(item_id::Int, experiment_id::Int)
    _link_entity("items", item_id, "experiments", experiment_id)
    return nothing
end

"""
    unlink_item_from_experiment(item_id::Int, experiment_id::Int)

Remove a link from an item to an experiment.
"""
function unlink_item_from_experiment(item_id::Int, experiment_id::Int)
    _unlink_entity("items", item_id, "experiments", experiment_id)
    return nothing
end

"""
    list_item_experiment_links(item_id::Int) -> Vector{Dict}

List all experiment links on an item.
"""
list_item_experiment_links(item_id::Int) = _list_entity_links("items", item_id, "experiments")

# =============================================================================
# Item ↔ Item links
# =============================================================================

"""
    link_items(id1::Int, id2::Int)

Create a link between two items.

# Example
```julia
link_items(7, 12)  # Link item 7 → item 12
```
"""
function link_items(id1::Int, id2::Int)
    _link_entity("items", id1, "items", id2)
    return nothing
end

"""
    unlink_items(id1::Int, id2::Int)

Remove a link between two items.
"""
function unlink_items(id1::Int, id2::Int)
    _unlink_entity("items", id1, "items", id2)
    return nothing
end

"""
    list_item_links(id::Int) -> Vector{Dict}

List all item-to-item links on an item.
"""
list_item_links(id::Int) = _list_entity_links("items", id, "items")
