# eLabFTW Integration Review

Comprehensive review of QPS.jl's eLabFTW integration (`src/elabftw.jl`), covering API correctness, missing workflows, usability, and code quality.

---

## 1. API Correctness Issues (Bugs)

| Issue | Location | Severity |
|-------|----------|----------|
| **`category_id` should be `category`** | `elabftw.jl:292` | High — category is silently ignored on experiment creation |
| **`metadata` double-encoded as string** | `elabftw.jl:295, 344` | High — `JSON.json(metadata)` produces a string, but API v2 expects a JSON object. The outer `JSON.json(body_dict)` then double-serializes it |
| **File handle leak in `_elabftw_upload`** | `elabftw.jl:1044` | Medium — `open(filepath)` is never explicitly closed if the upload fails |
| **Missing `content_type` for Markdown** | `create_experiment`, `update_experiment` | Medium — `format_results()` outputs Markdown but `content_type: 2` is never set, so eLabFTW may render it as HTML and garble the tables |

### Details

**`category_id` bug:** Any call like `create_experiment(title="test", category=5)` sends `{"category_id": 5}` instead of `{"category": 5}`. eLabFTW ignores the unknown field silently.

**Fix:** Line 292, change `payload["category_id"] = category` to `payload["category"] = category`.

**Metadata bug:** `JSON.json(metadata)` produces a JSON *string*, which then gets serialized again by the outer `JSON.json(body_dict)`. The server receives `{"metadata": "{\"key\": \"val\"}"}` instead of `{"metadata": {"key": "val"}}`.

**Fix:** Lines 295 and 344, change `payload["metadata"] = JSON.json(metadata)` to `payload["metadata"] = metadata`.

**Content type fix:** When body contains Markdown (e.g., from `format_results()`), add `payload["content_type"] = 2` to tell eLabFTW to render it as Markdown instead of HTML.

**File handle fix:** In `_elabftw_upload`, wrap the file open in a `do` block or use `try/finally` to ensure the handle is closed on error.

---

## 2. Missing High-Value Workflows for Spectroscopists

These are common experimentalist workflows that the eLabFTW API v2 supports but are not exposed in QPS.jl:

| Missing Feature | Why It Matters for Spectroscopists | API Support |
|---|---|---|
| **Experiment templates** | A "pump-probe measurement" or "FTIR peak fit" template pre-fills fields, steps, and metadata structure. Students don't forget required info. | `POST /experiments` with `template` param |
| **Steps / procedure checklists** | Track analysis progress: "Load data", "Baseline correct", "Fit peaks", "Generate figure". Visible in web UI. | `/experiments/{id}/steps` CRUD |
| **Link experiments together** | Link an FTIR characterization to its pump-probe follow-up, or link a sample preparation to all measurements on it. | `/experiments/{id}/experiments_links` |
| **Link experiments to items** | Connect an experiment to a sample or instrument record in the database. | `/experiments/{id}/items_links` |
| **Structured metadata (extra_fields)** | Instead of free-form tags, define typed fields: "Laser wavelength (nm)", "Pump power (mW)", "Temperature (K)" with units, validation, and dropdowns. | `metadata.extra_fields` with type/units/options |
| **Experiment status** | Track workflow state: "Running", "Analysis complete", "Ready for review", "Published". | `status` field (integer ID) |
| **Lock/sign experiments** | Freeze a completed experiment so it can't be accidentally modified. Digital signature for data integrity. | `PATCH` with `action: lock/sign` |
| **Comments** | Advisor can leave review comments on a student's experiment without editing the body. | `/experiments/{id}/comments` |
| **Export to PDF/ELN** | Export experiment as archival PDF or RO-Crate (.eln) for publication supplementary material. | `GET /experiments/{id}?format=pdf` |

### Priority ranking

The three most impactful additions are **templates**, **steps**, and **experiment links** — they directly address the lab transformation goals of standardized workflows and knowledge retention.

---

## 3. Usability Issues for Beginners

### Raw Dict return types — no pretty output

`list_experiments()` and `search_experiments()` return raw `Vector{Dict}` from the API JSON. A beginning student gets a wall of nested dictionaries with fields like `canread_base`, `elabid`, `locked`, etc. There's no pretty-print or summary view.

**Suggestion:** A `print_experiments(results)` function that shows a clean table (ID, title, date, tags, status) would make the REPL experience dramatically better.

### Inconsistent output feedback

- `delete_experiment()` uses `println()` — confirms deletion
- `log_to_elab()` uses `println()` — confirms logging with URL
- `create_experiment()` returns silently (just the ID)
- `tag_experiment()` returns silently

Some operations print confirmation, others don't. A student may wonder "did it work?" after `tag_experiment()`.

### `log_to_elab` two-argument form is hidden

The `log_to_elab(spec, result; ...)` method with auto-tagging is the "recommended" workflow per the CLAUDE.md, but:
- It requires an `AnnotatedSpectrum` — if a student has a `TATrace` or raw data, they can't use auto-tagging
- The two forms use different keyword argument names (`tags` vs `extra_tags`) which is confusing

### No connection test

There's no `test_elabftw_connection()` or status check. If a student misconfigures the URL or API key, they won't know until the first API call fails with an opaque HTTP error.

**Suggestion:** Add a `test_connection()` that hits `GET /api/v2/users/me` and prints the user info, or a clear error if it fails.

### Error messages hide server responses

HTTP errors (lines 950-960) say things like `"eLabFTW request failed with status $status"` without including the response body, which often contains a helpful error message from the server.

---

## 4. Code Verbosity / DRY Issues

### Duplicated error handling (~80 lines)

The five `_elabftw_*` helper functions (`_request`, `_post`, `_patch`, `_delete`, `_upload`) each repeat nearly identical `try/catch` blocks with the same status code checks. This could be a single `_handle_elabftw_error(e, url)` helper.

### Duplicated pagination loops (~20 lines x3)

The three batch operations (`delete_experiments`, `tag_experiments`, `update_experiments`) each contain an identical pagination loop (lines 596-603, 658-664, 716-722). Should be extracted into a shared `_find_all_experiments(; query, tags) -> Vector{Dict}` helper.

### Stale module docstring

The file's top docstring (lines 1-32) says "Provides **read-only** access to eLabFTW as a sample registry" — but the file now contains a full write API, batch operations, and experiment logging. This will confuse anyone reading the source.

---

## 5. Test Coverage Gaps

| What's Tested | What's Not Tested |
|---|---|
| Guard clauses (disabled -> error) | Actual HTTP interaction (no mock/integration tests) |
| `tags_from_sample` logic | `_parse_elabftw_item` metadata extraction |
| `format_results` output | `_normalize_field_name` edge cases |
| Batch operations require filters | `download_elabftw_file` caching logic |
| | URL construction / query parameter encoding |
| | `log_to_elab` two-argument method |
| | `create_experiment` payload construction (where the bugs are) |

The tests only verify that functions error when eLabFTW is disabled. There are no tests with mocked HTTP responses to verify correct request construction, URL building, or response parsing. This means the `category_id` and `metadata` bugs went undetected.

---

## 6. eLabFTW API Version Notes

- **Current eLabFTW version:** 5.3.11 (API v2, OpenAPI spec 2.0.0)
- **Base path:** `/api/v2/`
- **API v1 fully removed** in eLabFTW 5.0 — QPS.jl correctly uses v2 endpoints
- **Authentication:** API key in `Authorization` header (no "Bearer" prefix) — QPS.jl does this correctly
- **Metadata change in 5.0:** `metadata` field is returned as parsed JSON object, not a string

---

## 7. Prioritized Recommendations

### Priority 1 — Fix bugs
1. `"category_id"` -> `"category"` in `create_experiment`
2. Remove `JSON.json()` wrapping of metadata (let it serialize as nested object)
3. Set `"content_type" => 2` when body contains Markdown
4. Close file handle properly in `_elabftw_upload`

### Priority 2 — High-value missing features
5. `add_step()` / `list_steps()` — analysis procedure tracking
6. `link_experiments()` — connect related analyses
7. `create_from_template()` — standardized experiment creation
8. `set_status()` — workflow state tracking
9. `lock_experiment()` — finalize completed work

### Priority 3 — Usability
10. `print_experiments()` or a lightweight summary display for search/list results
11. `test_connection()` — verify eLabFTW is reachable and API key works
12. Include response body in error messages
13. Fix stale module docstring

### Priority 4 — Code quality
14. Extract shared HTTP error handling into a single wrapper
15. Extract shared pagination loop into `_find_all_experiments`
16. Add mock HTTP tests for request construction
