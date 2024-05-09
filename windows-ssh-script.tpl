add-content -path "C:\Users\windowsuser\.ssh\config" -value @'

Host ${hostname}
  Hostname ${hostname}
  User ${user}
  IdentityFile ${IdentityFile}
'@
