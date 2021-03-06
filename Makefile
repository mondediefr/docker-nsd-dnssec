NAME = mondedie/nsd-dnssec:testing

all: build-no-cache init fixtures run clean
all-fast: build init fixtures run clean
no-build: init fixtures run clean

build-no-cache:
	docker build --no-cache -t $(NAME) .

build:
	docker build -t $(NAME) .

init:
	docker run \
		--name nsd_unsigned --detach --tty \
		-v "$(shell pwd)/test/config/nsd.conf":/etc/nsd/nsd.conf \
		-v "$(shell pwd)/test/config/db.example.org":/zones/db.example.org \
		$(NAME)

	docker run \
		--name nsd_default --detach --tty \
		-v "$(shell pwd)/test/config/nsd.conf":/etc/nsd/nsd.conf \
		-v "$(shell pwd)/test/config/db.example.org":/zones/db.example.org \
		$(NAME)

fixtures:
	docker exec nsd_default keygen example.org
	docker exec nsd_default signzone example.org $(shell date -d "+4 months" +'%Y%m%d%H%M%S')

run:
	./test/bats/bin/bats --pretty --timing test/tests.bats

clean:
	docker stop nsd_unsigned nsd_default || true
	docker rm --force nsd_unsigned nsd_default || true
	docker system prune --all --volumes --force
