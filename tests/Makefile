.PHONY:articles

all:articles

articles:
	../_build/install/default/bin/patoline -I ../_build --extra-hyph-dir ../hyphs --extra-fonts-dir ../fonts --format FormatArticle min.txp
	../_build/install/default/bin/patoline -I ../_build --extra-hyph-dir ../hyphs --extra-fonts-dir ../fonts test_small_fraction.txp
	../_build/install/default/bin/patoline -I ../_build --extra-hyph-dir ../hyphs --extra-fonts-dir ../fonts test_virgule.txp
	../_build/install/default/bin/patoline -I ../_build --extra-hyph-dir ../hyphs --extra-fonts-dir ../fonts test_break_badness.txp
	../_build/install/default/bin/patoline -I ../_build --extra-hyph-dir ../hyphs --extra-fonts-dir ../fonts test_distance.txp

clean:
	rm -rf *_.cmi *.cmi *_.cmx *.cmx *_.dep *_.o *.o *.tdep *.tdx *.tgx *_.tml *.tmx *.ttml *.pdf *~
