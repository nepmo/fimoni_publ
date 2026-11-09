cd /path/to/fimoni/docker || exit;
if [ "$1" = "test" ]; then
  shift
  docker compose run --rm -w /path/to/fimoni/py dpfimoni bash -c 'python dpfimoni_fimoni.py test'
else
  docker compose run --rm -w /path/to/fimoni/py dpfimoni bash -c 'python dpfimoni_fimoni.py'
fi