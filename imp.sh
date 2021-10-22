ls -d aptconf/trusted.gpg.d/* | while read k; do gpg --no-default-keyring --keyring ./keyring.gpg --import < "$k"; done > msg 2>&1
