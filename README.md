# dollhouse

A tiny container that runs nginx and exposes it through an ngrok tunnel.

## Run

```sh
docker run --rm -p 4040:4040 \
  -e NGROK_AUTHTOKEN=your-ngrok-authtoken \
  dollhouse
```

By default, the entrypoint starts nginx and runs:

```sh
ngrok http http://127.0.0.1:80
```

## Routes

Set `DOLLHOUSE_ROUTES` to generate nginx routes before nginx starts. Routes are
space- or comma-separated. Each route is one top-level path segment; Dollhouse
does not accept nested route paths like `foo/bar`.

Simple form:

```sh
-e DOLLHOUSE_ROUTES="rysa elma"
```

implies:

```txt
/rysa/ -> http://rysa:80/
/elma/ -> http://elma:80/
```

Advanced form:

```sh
-e DOLLHOUSE_ROUTES="rysa:rysa:3000 elma:elma-api:8080"
```

implies:

```txt
/rysa/ -> http://rysa:3000/
/elma/ -> http://elma-api:8080/
```

You can change the simple-form default port with `DOLLHOUSE_DEFAULT_PORT`:

```sh
-e DOLLHOUSE_DEFAULT_PORT=3000 -e DOLLHOUSE_ROUTES="rysa elma"
```

You can pass different ngrok arguments after the image name:

```sh
docker run --rm -e NGROK_AUTHTOKEN=your-ngrok-authtoken dollhouse http --url example.ngrok.app http://127.0.0.1:80
```
