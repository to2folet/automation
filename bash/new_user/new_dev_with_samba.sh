#!/bin/bash

# script which create new user for developers
# location /scripts/new_user/new_dev_with_samba.sh

# sudo mkdir -p /scripts/new_user/ && sudo vi /scripts/new_user/new_dev_with_samba.sh && sudo chmod 700 /scripts/new_user/new_dev_with_samba.sh && /scripts/new_user/new_dev_with_samba.sh

# to check if the user was successfully added into
# sudo vim /etc/ssh/sshd_config

# to set value of DEVELOPER and also to copy public key to the DEVELOPERS_KEY
DEVELOPER="username"
DEVELOPERS_KEY="ssh-rsa U50Ilo5opRh8UzD3WnW4U3ocYrqHy8C9Sw6n"
HOSTNAME=$(hostname)

TIME=$(date "+.%Y%m%d-%H%M%S")

create_dev() {
  echo "Please provide the password for $DEVELOPER: "
  read -r password

  # the password has to be passed hashed to the useradd command
  pass=$(perl -e 'print crypt($ARGV[0], "password")' "$password")
  useradd -m -p "$pass" $DEVELOPER -g sudo -s /bin/bash

  # install $DEVELOPER's public key in his user account
  mkdir /home/$DEVELOPER/.ssh

  echo "$DEVELOPERS_KEY" | tee -a /home/$DEVELOPER/.ssh/authorized_keys
  chown -R "$DEVELOPER" /home/$DEVELOPER/.ssh
  sed -e "/AllowUsers/s/$/ $DEVELOPER/" -i /etc/ssh/sshd_config > /dev/null 2>&1 &

  service ssh restart  
}

configure_samba() {
  # Prepare Samba ENV
  SAMBA_CONF="/etc/samba/smb.conf"

  sudo cp $SAMBA_CONF $SAMBA_CONF"${TIME}"
  echo "

  [DEVELOPER_DevGit]
  path = /home/$DEVELOPER/gitrepo
  available = yes
  valid users = $DEVELOPER
  read only = no
  browsable = yes
  public = yes
  writable = yes

  " >> $SAMBA_CONF

  sudo smbpasswd -a $DEVELOPER

  sudo service smbd restart
}

# create a user for <DEVELOPER> if it doesn't already exist
if /bin/grep -E "^$DEVELOPER" /etc/passwd; then
  echo "A user account already exists for $DEVELOPER, skipping creation"
else
  echo "Creating user account for $DEVELOPER"
  
  create_dev

  configure_samba  

fi
