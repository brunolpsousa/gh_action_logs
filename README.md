# gh_action_logs.sh

### A simple Bash script to delete GitHub Actions logs

You must provide your `username` and `repository` of choice, as well as a `token` with admin rights over the provided repository.

Run the script with:

```sh
chmod +x gh_action_logs.sh
./gh_action_logs.sh
```

Or without any delete request (it will only try to download the logs from GitHub API):

```sh
./gh_action_logs.sh --dry-run
```

<br>

**Note:**: this script will delete all logs in the repository.

**Note:** the filter on the logs is not very strict at the moment and may select unrelated `ids`, although _theoretically_ the worst that could happen would be return a `404` error.

**Note:** this comes with no warranty or support of any kind. Refer to the license for more information.
