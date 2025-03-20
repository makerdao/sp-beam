PATH := ~/.solc-select/artifacts/solc-0.8.24:~/.solc-select/artifacts/solc-0.8.21:~/.solc-select/artifacts/solc-0.5.12:~/.solc-select/artifacts:$(PATH)
certora-dspc:; PATH=${PATH} certoraRun certora/DSPC.conf$(if $(rule), --rule $(rule),)

