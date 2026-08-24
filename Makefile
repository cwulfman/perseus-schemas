# ============================================================
# Configuration
# ============================================================
TEI_XSL_DIR := $(HOME)/tei-xsl/xml/tei/stylesheet
SAXON_JAR   := /opt/homebrew/Cellar/saxon/13.0/libexec/saxon-he-13.0.jar
P5SUBSET    := $(HOME)/tei-xsl/p5subset.xml
ODD2ODD_XSL := $(TEI_XSL_DIR)/odds/odd2odd.xsl
ODD2RNG_XSL := $(TEI_XSL_DIR)/odds/odd2relax.xsl

TRANG       := trang

SAXON       := java -jar $(SAXON_JAR)

# Pass 1 flags: expand ODD against its source chain up to p5subset.xml
# defaultSource  — fallback P5 vocabulary for any ODD with no source= attribute
# currentDirectory — base URI for resolving relative source= references (e.g. "tei_bare.odd")
ODDFLAGS    := defaultSource=$(P5SUBSET) currentDirectory=$(CURDIR)/

# ============================================================
# Targets
# ============================================================
.PHONY: all clean check

all: tei_minimal.compiled.odd perseus_base.rnc perseus_prose.rnc perseus_verse.rnc perseus_drama.rnc perseus_lexical.rnc

# ------ tei_bare (pedagogical reference, not part of the build chain) -------
tei_bare.compiled.odd: tei_bare.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

# ------ tei_minimal --------------------------------------------
# Pass 1: expand tei_minimal.odd against p5subset.xml.
# This is the recommended TEI starting point for project customizations.
tei_minimal.compiled.odd: tei_minimal.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

# ------ perseus_base -------------------------------------------
# source="tei_minimal.compiled.odd" in schemaSpec chains from the compiled
# tei_minimal, inheriting its elements and applying perseus customizations.
perseus_base.compiled.odd: perseus_base.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

perseus_base.rng: perseus_base.compiled.odd
	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

perseus_base.rnc: perseus_base.rng
	$(TRANG) $< $@

# ------ perseus_prose ------------------------------------------
perseus_prose.compiled.odd: perseus_prose.odd perseus_base.compiled.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

perseus_prose.rng: perseus_prose.compiled.odd
	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

perseus_prose.rnc: perseus_prose.rng
	$(TRANG) $< $@

# ------ perseus_verse ------------------------------------------
perseus_verse.compiled.odd: perseus_verse.odd perseus_base.compiled.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

perseus_verse.rng: perseus_verse.compiled.odd
	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

perseus_verse.rnc: perseus_verse.rng
	$(TRANG) $< $@

# ------ perseus_drama ------------------------------------------
perseus_drama.compiled.odd: perseus_drama.odd perseus_base.compiled.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

perseus_drama.rng: perseus_drama.compiled.odd
	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

perseus_drama.rnc: perseus_drama.rng
	$(TRANG) $< $@

# ------ perseus_lexical ----------------------------------------
perseus_lexical.compiled.odd: perseus_lexical.odd perseus_base.compiled.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

perseus_lexical.rng: perseus_lexical.compiled.odd
	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

perseus_lexical.rnc: perseus_lexical.rng
	$(TRANG) $< $@

# ------ future ODDs (uncomment as created) ---------------------
# perseus_early_modern.compiled.odd: perseus_early_modern.odd \
#     perseus_base.compiled.odd $(P5SUBSET)
#	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)
# perseus_early_modern.rng: perseus_early_modern.compiled.odd
#	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

# perseus_classical.compiled.odd: perseus_classical.odd \
#     perseus_base.compiled.odd $(P5SUBSET)
#	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)
# perseus_classical.rng: perseus_classical.compiled.odd
#	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

# perseus_reference.compiled.odd: perseus_reference.odd \
#     perseus_base.compiled.odd $(P5SUBSET)
#	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)
# perseus_reference.rng: perseus_reference.compiled.odd
#	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

# ------ utilities -----------------------------------------------
check:
	@test -f "$(SAXON_JAR)"   || (echo "ERROR: Saxon JAR not found at $(SAXON_JAR)"; exit 1)
	@test -f "$(P5SUBSET)"    || (echo "ERROR: p5subset.xml not found at $(P5SUBSET)"; exit 1)
	@test -f "$(ODD2ODD_XSL)" || (echo "ERROR: odd2odd.xsl not found at $(ODD2ODD_XSL)"; exit 1)
	@test -f "$(ODD2RNG_XSL)" || (echo "ERROR: odd2relax.xsl not found at $(ODD2RNG_XSL)"; exit 1)
	@command -v $(TRANG) >/dev/null 2>&1 || (echo "ERROR: trang not found (brew install jing-trang)"; exit 1)
	@$(SAXON) -? 2>&1 | head -1
	@echo "Toolchain OK."

clean:
	rm -f *.rng *.rnc *.compiled.odd
