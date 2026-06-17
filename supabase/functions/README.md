# LIVA — Supabase Edge Functions

Three Deno/TypeScript functions power Phase 3 nutrition. All are **deployed** to the
`LIVA` project (`deqdmxbvvfatdakqqfnv`) with `verify_jwt = true`, and each **degrades
gracefully** (returns `{ "configured": false }`) when its secret is missing — so the app
builds and runs before any keys are set.

| Function | Purpose | Secrets required |
|----------|---------|------------------|
| `food-search` | Nutritionix instant search, barcode (`upc`) lookup, and full-macro detail (`natural/nutrients`, `search/item`) | `NUTRITIONIX_APP_ID`, `NUTRITIONIX_APP_KEY` |
| `meal-describe` | Claude (`claude-opus-4-8`) parses a free-text meal → items + macros (structured output) | `ANTHROPIC_API_KEY` |
| `meal-photo` | Claude vision → detected plate items, portions, macros, confidence | `ANTHROPIC_API_KEY` |

## Setting secrets (to enable live search + AI)

Supabase Dashboard → **Edge Functions → Secrets**, or via CLI:

```bash
supabase secrets set NUTRITIONIX_APP_ID=xxx NUTRITIONIX_APP_KEY=xxx --project-ref deqdmxbvvfatdakqqfnv
supabase secrets set ANTHROPIC_API_KEY=sk-ant-xxx --project-ref deqdmxbvvfatdakqqfnv
```

- **Nutritionix** app id/key: https://developer.nutritionix.com
- **Anthropic** API key: https://console.anthropic.com

## Notes
- The deployed function code is the source of truth (view/edit in the dashboard or via the
  Supabase MCP `get_edge_function`). Mirroring the `.ts` sources into this folder for version
  control is a recommended follow-up.
- Functions are invoked from the app through `supabase.functions.invoke(...)`, which forwards
  the signed-in user's JWT (so `verify_jwt` is satisfied automatically).
