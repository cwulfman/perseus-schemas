# ============================================================
# Configuration
# ============================================================
TEI_XSL_DIR := $(HOME)/tei-xsl/xml/tei/stylesheet
SAXON_JAR   := /opt/homebrew/Cellar/saxon/12.9/libexec/saxon-he-12.9.jar
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

all: tei_bare.compiled.odd perseus_base.rng perseus_base.rnc

# ------ tei_bare -----------------------------------------------
# Pass 1: expand tei_bare.odd against p5subset.xml.
# tei_bare.compiled.odd is a build intermediate only; no RNG is generated
# because no documents validate against tei_bare directly.
tei_bare.compiled.odd: tei_bare.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

# ------ perseus_base -------------------------------------------
# source="tei_bare.compiled.odd" in schemaSpec means odd2odd.xsl reads
# the fully-expanded parent specs from the compiled ODD, then applies
# the child's class deletions on top.
perseus_base.compiled.odd: perseus_base.odd tei_bare.compiled.odd $(P5SUBSET)
	$(SAXON) -s:$< -xsl:$(ODD2ODD_XSL) -o:$@ $(ODDFLAGS)

perseus_base.rng: perseus_base.compiled.odd
	$(SAXON) -s:$< -xsl:$(ODD2RNG_XSL) -o:$@

perseus_base.rnc: perseus_base.rng
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
