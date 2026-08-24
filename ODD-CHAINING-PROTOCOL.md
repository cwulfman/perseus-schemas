# Perseus ODD Chaining Protocol

How the Perseus schema family is structured, how ODD chaining actually behaves in our
toolchain, and the rules you must follow when editing these ODDs. Read this before touching
any `.odd` file.

---

## 1. The architecture

```
p5subset.xml  (full TEI P5 vocabulary, the defaultSource)
      │
      ▼  odd2odd
tei_minimal.compiled.odd
      │
      ▼  source="tei_minimal.compiled.odd"
perseus_base.odd  ──odd2odd──▶  perseus_base.compiled.odd   ◀── SINGLE SOURCE OF TRUTH
      │                                   │
      │ source="perseus_base.compiled.odd"
      ├──────────────┬──────────────┬─────────────┐
      ▼              ▼              ▼             ▼
perseus_prose   perseus_verse   perseus_drama   perseus_lexical
```

- **`perseus_base.odd` is the single source of truth.** Its `moduleRef … include="…"` lists
  define the curated subset of each TEI module that any Perseus document may use, plus
  Perseus-wide customizations (deleted attribute classes, the `@met` controlled vocabulary,
  the `drama` module, etc.).
- **The genre ODDs (`prose`/`verse`/`drama`) are thin.** They chain from
  `perseus_base.compiled.odd` and re-select base's curated modules with **bare** `moduleRef`s
  (no `include=`). They add only what genuinely differs between genres.

Build chain (see `Makefile`): each `.odd` is expanded by `odd2odd` (pass 1) into a
`.compiled.odd`, then `odd2relax` (pass 2) emits `.rng`, then `trang` emits `.rnc`. Both `.rng`
and `.rnc` are committed (the schema PI written by `set-schema.xsl` points at the `.rng`).

---

## 2. How `source=` chaining actually behaves (the rules)

These were established empirically against our toolchain (Saxon-HE 13, TEI Stylesheets).
Several are counterintuitive and have already caused real bugs.

### Rule 1 — `source=` does NOT auto-inherit. You must re-declare each module.

A `<schemaSpec source="perseus_base.compiled.odd">` with **no** `moduleRef`s compiles to an
empty 64-line grammar. The `source` only says *where to resolve declarations from*; it does
not pull anything in by itself. To include a module you must name it with a `moduleRef`.

### Rule 2 — a bare `moduleRef` inherits base's CURATED subset, not full TEI.

`<moduleRef key="core"/>` (no `include=`), resolved against `perseus_base.compiled.odd`, pulls
in exactly the elements **base curated** for `core` — not the full TEI core module.

> Verified: `q` is absent from the children (base doesn't list it), while `milestone` is
> present (base does). Add `q` to base's core list and every child gets it on the next build.

**This is the mechanism that gives us a single source of truth.** Children use bare
`moduleRef`s and stay in lockstep with base automatically.

### Rule 3 — an `include=` list on a child REPLACES, and silently drops the rest.

`<moduleRef key="core" include="p l sp"/>` does **not** mean "base's core plus these." It means
"only these," discarding every other base element. Short hand-maintained include lists in the
child ODDs were the original cause of ~31k validation errors (verse/drama were missing
`milestone`, `placeName`, `note`, `pb`, …), and they had also drifted out of sync with base
(prose had dropped `refState`). **Do not put `include=` lists on the genre ODDs.** Keep them
bare; curate in base only.

### Rule 4 — to add an element, it must be reachable in the SOURCE, under the right module.

`moduleRef key="X" include="…"` can only select elements the source actually defines for
module `X`. Two consequences we hit:

- **`<stage>` is in the `core` module, not `drama`.** `moduleRef key="drama" include="stage"`
  silently finds nothing. `stage` is curated in base's `core` include list; the `drama` module
  supplies only `castList castItem role roleDesc`.
- **A child cannot introduce a module base never compiled in.** `drama` elements are only
  available to `perseus_drama` because the `drama` module is declared in **base**. The child
  then re-selects it with a bare `<moduleRef key="drama"/>`. (Other genres simply omit that
  line, so they don't get cast lists.)

### Rule 5 — changing an attribute's value list requires `mode="add"` on the `valList`.

```xml
<classSpec ident="att.metrical" module="verse" mode="change" type="atts">
  <attList>
    <attDef ident="met" mode="change">
      <valList type="semi" mode="add">     <!-- mode="add" is REQUIRED -->
        <valItem ident="dactylic-hexameter">…</valItem>
        …
      </valList>
    </attDef>
  </attList>
</classSpec>
```

A bare `<valList type="semi">` under a `mode="change"` `attDef` is **silently dropped** by
`odd2odd` — no error, the values just never appear in the `.rng`. This is why the metrical
vocabulary went missing for a long time. Declare it **once in base**; verse and drama inherit
it via the `verse` module (no per-child override — which never worked anyway).

---

## 3. Editing recipes

| Goal | Where | How |
|---|---|---|
| Add an element corpus-wide (e.g. `q`, `num`, `emph`) | `perseus_base.odd` | add it to the relevant `moduleRef … include="…"` list. Rebuild all. Children inherit it. |
| Constrain an attribute's values corpus-wide | `perseus_base.odd` | `classSpec … mode="change"` with `valList … mode="add"` (Rule 5). |
| Add an element to ONE genre only | that genre's ODD | the element's module must exist in base; re-select it with a bare `moduleRef`, or add the specific element via an `elementRef`. |
| Remove an element from ONE genre only | that genre's ODD | `<elementSpec ident="X" mode="delete"/>` (subtract from the inherited superset). |
| Remove an element corpus-wide | `perseus_base.odd` | drop it from base's `include` list. |

**Default stance:** base is a permissive superset; genres differ by *adding* a module
(`drama`) or, rarely, *deleting* an element. We do not maintain parallel include lists.
(Empirically the corpus uses elements like `stage` across all genres, so a permissive base is
the right default; tighten per-genre only with evidence.)

---

## 4. Always verify after editing

```sh
make            # rebuild .compiled.odd / .rng / .rnc for all schemas
```

Then sanity-check the compiled `.rng` actually contains what you intended — `odd2odd` fails
silently (Rules 1, 4, 5), so an empty/short grammar will not raise an error:

```sh
grep -c '<define name="q"' perseus_prose.rng        # element present?
wc -l perseus_*.rng                                 # ~5,300+ lines; 64 means empty grammar
```

Finally, re-run the corpus validator (in `corpus-tools`) to measure impact and catch
regressions:

```sh
make -C ../corpus-tools validate-corpus \
  DATA_DIR=../data-local/canonical-greekLit/data \
  OUT_DIR=corpus-surveys/canonical-greekLit
```
