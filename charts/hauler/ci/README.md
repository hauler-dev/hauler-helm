# Hauler Helm Tests

## Values Files

Each file in this ci folder that ends in "-values.yaml" will represent another iteration for this test to run. No matter what, it will test for the Hauler Web and Registry servers on their default ports (8080 and 5000), so leave them enabled in the values files or tests will fail. The test name is the filename before "-values.yaml".

## Linting and Installing

"ct" or Chart-Testing tool will lint each possible helm install with its linter. After that succeeds, helm will install each iteration onto a k3s cluster. Finally a test pod will run curls against the running containers and make sure their output is what is in the Expected Output.

## Expected Output

The folder "ci/expected" represents the outputs the registry and web server will give after helm has installed them, their respective loaders run, and they are up and running. Each test should have two files named "test name"-reg-output.txt and "test name"-web-output.txt - for example awesome-test-reg-output.txt and awesome-test-web-output.txt would correspond with the ci directory's awesome-test-values.yaml.

## Nifty script

The script "test-maker.sh" can be used to help create output files based off of known good installations. Uncomment the needed parts (like helm install or uninstall, or output file creation) and then push these values and output files into the repo.

## See also

.github/workflows/helm-test.yaml in this repo
