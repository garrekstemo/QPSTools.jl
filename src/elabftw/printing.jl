# Pretty-printing for eLabFTW entities

"""
    print_experiments(experiments; io=stdout)

Print a formatted table of experiments. Pure formatting function — no API calls.

# Arguments
- `experiments::Vector` — Vector of experiment dicts (from `list_experiments` or `search_experiments`)
- `io::IO` — Output stream (default: stdout)

# Example
```julia
exps = search_experiments(tags=["ftir"])
print_experiments(exps)
```
"""
function print_experiments(experiments::Vector; io::IO=stdout)
    if isempty(experiments)
        println(io, "No experiments found.")
        return
    end

    println(io, rpad("ID", 8), rpad("Date", 12), rpad("Title", 52), "Tags")
    println(io, repeat("-", 80))

    for exp in experiments
        id = string(get(exp, "id", ""))
        raw_date = string(get(exp, "date", ""))
        date = length(raw_date) >= 10 ? raw_date[1:10] : raw_date
        raw_title = string(get(exp, "title", ""))
        t = length(raw_title) > 50 ? raw_title[1:47] * "..." : raw_title
        tags_list = get(exp, "tags", [])
        tag_strs = [string(get(tag, "tag", tag)) for tag in tags_list]
        tags_str = join(tag_strs, ", ")
        println(io, rpad(id, 8), rpad(date, 12), rpad(t, 52), tags_str)
    end
end

"""
    print_items(items; io=stdout)

Print a formatted table of items/resources. Pure formatting function — no API calls.

# Arguments
- `items::Vector` — Vector of item dicts (from `list_items` or `search_items`)
- `io::IO` — Output stream (default: stdout)

# Example
```julia
items = search_items(tags=["instrument"])
print_items(items)
```
"""
function print_items(items::Vector; io::IO=stdout)
    if isempty(items)
        println(io, "No items found.")
        return
    end

    println(io, rpad("ID", 8), rpad("Category", 16), rpad("Title", 44), "Tags")
    println(io, repeat("-", 80))

    for item in items
        id = string(get(item, "id", ""))
        cat = string(get(item, "category_title", get(item, "category", "")))
        cat = length(cat) > 14 ? cat[1:11] * "..." : cat
        raw_title = string(get(item, "title", ""))
        t = length(raw_title) > 42 ? raw_title[1:39] * "..." : raw_title
        tags_list = get(item, "tags", [])
        tag_strs = [string(get(tag, "tag", tag)) for tag in tags_list]
        tags_str = join(tag_strs, ", ")
        println(io, rpad(id, 8), rpad(cat, 16), rpad(t, 44), tags_str)
    end
end

"""
    print_tags(tags::Vector; io::IO=stdout)

Pretty-print tag lists from `list_tags` (entity tags) or `list_team_tags` (team tags).

# Examples
```julia
print_tags(list_tags(experiment_id))
print_tags(list_team_tags())
```
"""
function print_tags(tags::Vector; io::IO=stdout)
    if isempty(tags)
        println(io, "No tags found.")
        return
    end

    # Detect entity vs team tags by key presence
    is_team = haskey(first(tags), "item_count")

    if is_team
        println(io, rpad("ID", 8), rpad("Tag", 32), "Experiments")
        println(io, repeat("-", 52))
        for t in tags
            id = string(get(t, "id", ""))
            tag = string(get(t, "tag", ""))
            count = string(get(t, "item_count", ""))
            println(io, rpad(id, 8), rpad(tag, 32), count)
        end
    else
        println(io, rpad("ID", 8), "Tag")
        println(io, repeat("-", 32))
        for t in tags
            id = string(get(t, "tag_id", ""))
            tag = string(get(t, "tag", ""))
            println(io, rpad(id, 8), tag)
        end
    end
end
