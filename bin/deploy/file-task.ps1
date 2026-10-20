$ErrorActionPreference = "Stop"

# Run a file task as root inside a throwaway Alpine container, with the project mounted at /p. The
# task itself is the POSIX `file-task` script next to this one; see it for why and for the usage.
#
# NOTE: assumes it is executed from the project directory.

$projectDir = (Get-Location).ProviderPath

docker run --rm -u 0 --network none -e WADDLE_FILE_TASK=1 -v "${projectDir}:/p" -w /p `
    alpine sh ./bin/deploy/file-task @args
if ($LASTEXITCODE -ne 0) { throw "File task '$($args[0])' failed." }
