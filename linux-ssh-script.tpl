cat << EOF >> ~/.ssh/config

Host ${hostname}
  HostName ${hostname}
  USER ${user}
  IdentityFile ${IdentityFile}
EOF
