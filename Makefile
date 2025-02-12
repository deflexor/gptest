DEPS = Plack Template::Alloy DBI DBD::SQLite HTML::Escape

install-deps:
	cpanm -n $(DEPS)

run:
	plackup -p 5000 -r app.psgi

.PHONY: install-deps run
