install-deps:
    cpanm -n Plack Template::Alloy DBI DBD::Pg HTML::Escape

run:
    plackup -p 5000 -r app.psgi

.PHONY: install-deps run
