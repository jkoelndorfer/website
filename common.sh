function usage() {
    echo 'You must pass the name of the environment as the first argument to this script.' >&2
    echo 'Valid values are: dev, prod' >&2
}

if [[ "$env" == 'prod' ]]; then
    base_url='https://john.koelndorfer.com'
elif [[ "$env" == 'dev' ]]; then
    base_url='https://dev.john.koelndorfer.com'
else
    usage
    exit 1
fi
